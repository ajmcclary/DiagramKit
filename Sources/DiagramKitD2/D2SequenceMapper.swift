import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Builds a `SequenceDiagram` from a parsed `D2Document`.
///
/// The mapper walks D2 statements in declaration order and emits a
/// `SequenceItem` timeline. The result is canonical: derived computed
/// arrays (`actors`, `messages`, `blocks`, `boxes`, `notes`) reconstruct
/// from `items` via the existing `SequenceDiagram` computed properties.
struct D2SequenceMapper {

    func map(
        _ document: D2Document,
        markers: [RecoveryMarker<D2RecoveryMarker.Kind>]
    ) -> (SequenceDiagram, [DiagramDiagnostic]) {
        var items: [SequenceItem] = []
        var diagnostics: [DiagramDiagnostic] = []
        var seenActorIDs: Set<String> = []

        func registerActor(_ id: String, label: String, type: ParticipantType, isExplicit: Bool) {
            guard !seenActorIDs.contains(id) else { return }
            items.append(.actor(SequenceActor(id: id, label: label, type: type, isExplicit: isExplicit)))
            seenActorIDs.insert(id)
        }

        for stmt in document.statements {
            switch stmt {
            case .nodeDefinition(let def):
                // Skip the dispatch-signal node itself
                // (`shape: sequence_diagram` at top level).
                if def.id == "shape" && def.label == "sequence_diagram" { continue }
                let label = def.label ?? def.id
                let type = D2SequenceMapper.participantType(forShape: def.shape) ?? .participant
                if let shape = def.shape, type == .participant, shape != "sequence_diagram" {
                    diagnostics.append(.lossyTransform(
                        .shapeDowngrade,
                        message: "D2 shape '\(shape)' has no ParticipantType mapping; defaulted to .participant"
                    ))
                }
                registerActor(def.id, label: label, type: type, isExplicit: true)

            case .edgeDefinition(let edge):
                registerActor(edge.source, label: edge.source, type: .participant, isExplicit: false)
                registerActor(edge.target, label: edge.target, type: .participant, isExplicit: false)
                let arrow: SequenceArrowType = {
                    switch edge.edgeKind {
                    case .bidirectional: return .bidirectionalSolid
                    case .directional, .undirected: return .solid
                    }
                }()
                items.append(.message(SequenceMessage(
                    from: edge.source,
                    to: edge.target,
                    label: edge.label ?? "",
                    arrowType: arrow
                )))

            default:
                break
            }
        }

        // Marker recovery — Task 3 only honors actor-kind and arrow-type.
        // Tasks 4–5 expand this to blocks, boxes, notes, etc.
        var working = items
        applyActorKindMarkers(&working, markers: markers)
        applyArrowTypeMarkers(&working, markers: markers)

        return (SequenceDiagram(items: working), diagnostics)
    }

    private func applyActorKindMarkers(
        _ items: inout [SequenceItem],
        markers: [RecoveryMarker<D2RecoveryMarker.Kind>]
    ) {
        for marker in markers {
            guard case .seqActorKind(let id, let raw) = marker.kind else { continue }
            guard let type = ParticipantType(rawValue: raw) else { continue }
            for idx in items.indices {
                if case .actor(var actor) = items[idx], actor.id == id {
                    actor.type = type
                    items[idx] = .actor(actor)
                }
            }
        }
    }

    private func applyArrowTypeMarkers(
        _ items: inout [SequenceItem],
        markers: [RecoveryMarker<D2RecoveryMarker.Kind>]
    ) {
        var msgIdx = -1
        for idx in items.indices {
            if case .message(var msg) = items[idx] {
                msgIdx += 1
                let captured = msgIdx
                for marker in markers {
                    guard case .seqArrowType(let mIdx, let raw) = marker.kind,
                          mIdx == captured,
                          let arrow = SequenceArrowType(rawValue: raw)
                    else { continue }
                    msg.arrowType = arrow
                }
                items[idx] = .message(msg)
            }
        }
    }

    static func participantType(forShape shape: String?) -> ParticipantType? {
        guard let shape else { return .participant }
        switch shape {
        case "person":   return .actor
        case "cylinder": return .database
        case "queue":    return .queue
        case "oval":     return .boundary
        case "hexagon":  return .control
        case "cloud":    return .entity
        case "page":     return .collections
        default:         return nil
        }
    }
}
