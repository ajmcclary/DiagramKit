import Foundation
import DiagramKitModel
import DiagramKitImport

/// Maps `PlantUMLSequenceAST` to `DiagramPayload.sequenceDiagram(SequenceDiagram)`.
public struct PlantUMLSequenceMapper {

    public init() {}

    public func map(_ ast: PlantUMLSequenceAST) -> (diagram: SequenceDiagram, diagnostics: [DiagramDiagnostic]) {
        var items: [SequenceItem] = []
        var diagnostics: [DiagramDiagnostic] = []
        var knownActorIds = Set<String>()

        // Emit actor items first from participants, preserving box grouping.
        var openBox: (title: String?, fill: String)?
        for p in ast.participants {
            let participantBox = p.boxName.map { (title: Optional($0), fill: p.boxFill ?? "transparent") }
            let boxChanged = openBox?.title != participantBox?.title || openBox?.fill != participantBox?.fill
            if boxChanged {
                if openBox != nil {
                    items.append(.boxEnd)
                }
                if let participantBox {
                    items.append(.boxStart(fill: participantBox.fill, title: participantBox.title, wrap: false))
                }
                openBox = participantBox
            }

            let actor = _mapParticipant(p)
            knownActorIds.insert(actor.id)
            items.append(.actor(actor))
        }
        if openBox != nil {
            items.append(.boxEnd)
        }

        // Walk AST items and emit SequenceItems
        var openBlockTypes: [String] = []  // stack of open block types

        for item in ast.items {
            switch item {
            case .message(let msg):
                let from = msg.from
                let to = msg.to

                // Handle return message
                if from == "return" {
                    // "return" in PlantUML is deactivate + dotted message
                    // Without context of previous sender, we emit activation end
                    // and skip the message if we can't determine direction
                    continue
                }

                // Ensure actors exist
                _ensureActor(&items, &knownActorIds, from)
                _ensureActor(&items, &knownActorIds, to)

                let seqArrowType = _mapArrowType(msg.arrow)
                let seqMsg = SequenceMessage(
                    from: from,
                    to: to,
                    label: msg.label ?? "",
                    arrowType: seqArrowType,
                    activate: msg.activate,
                    deactivate: msg.deactivate
                )
                items.append(.message(seqMsg))

            case .note(let note):
                items.append(.note(SequenceNote(
                    actorIds: note.targets,
                    text: note.text,
                    position: note.position.rawValue
                )))

            case .activate(let target):
                _ensureActor(&items, &knownActorIds, target)
                items.append(.activationStart(actorId: target))

            case .deactivate(let target):
                _ensureActor(&items, &knownActorIds, target)
                items.append(.activationEnd(actorId: target))

            case .groupStart(let label, let kind):
                let typeStr = kind.rawValue
                openBlockTypes.append(typeStr)
                items.append(.blockStart(type: typeStr, label: label))

            case .groupEnd:
                if let typeStr = openBlockTypes.popLast() {
                    items.append(.blockEnd(type: typeStr))
                }

            case .divergent(let label):
                if let typeStr = openBlockTypes.last {
                    items.append(.blockDivider(type: typeStr, label: label))
                }

            case .autoNumberStart:
                items.append(.autonumberEvent(start: 1, step: 1, visible: true))

            case .autoNumberStop:
                items.append(.autonumberEvent(start: 1, step: 1, visible: false))

            case .unsupported(let feature, let line):
                diagnostics.append(PlantUMLDiagnostics.unsupported(feature, line: line))
            }
        }

        // Close any remaining open blocks
        while let typeStr = openBlockTypes.popLast() {
            items.append(.blockEnd(type: typeStr))
        }

        let diagram = SequenceDiagram(items: items)
        return (diagram: diagram, diagnostics: diagnostics)
    }

    // MARK: - Helpers

    private func _mapParticipant(_ p: PlantUMLParticipant) -> SequenceActor {
        let participantType: ParticipantType = p.kind == .actor ? .actor : .participant
        let label = p.displayName ?? p.alias
        return SequenceActor(
            id: p.alias,
            label: label,
            type: participantType,
            boxId: p.boxName,
            isExplicit: true
        )
    }

    private func _ensureActor(_ items: inout [SequenceItem], _ actorIds: inout Set<String>, _ id: String) {
        guard !actorIds.contains(id) else { return }
        actorIds.insert(id)
        items.append(.actor(SequenceActor(id: id, label: id, type: .participant, isExplicit: false)))
    }

    private func _mapArrowType(_ arrow: PlantUMLArrowType) -> SequenceArrowType {
        switch arrow {
        case .solid:         return .solid
        case .dotted:        return .dotted
        case .open:          return .dottedOpen
        case .circle:        return .solidOpen
        case .cross:         return .solidCross
        case .bidirectional: return .bidirectionalSolid
        }
    }
}
