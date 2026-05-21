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

    private enum ContainerFrame {
        case block(label: String)
        case box(label: String)
    }

    func map(
        _ document: D2Document,
        markers: [RecoveryMarker<D2RecoveryMarker.Kind>]
    ) -> (SequenceDiagram, [DiagramDiagnostic]) {
        var items: [SequenceItem] = []
        var diagnostics: [DiagramDiagnostic] = []
        var seenActorIDs: Set<String> = []
        var containerStack: [ContainerFrame] = []

        func registerActor(_ id: String, label: String, type: ParticipantType, isExplicit: Bool) {
            guard !seenActorIDs.contains(id) else { return }
            items.append(.actor(SequenceActor(id: id, label: label, type: type, isExplicit: isExplicit)))
            seenActorIDs.insert(id)
        }

        func inferBlockType(label: String) -> (type: String, inferred: Bool) {
            for prefix in ["alt_", "opt_", "loop_", "par_", "critical_", "break_", "rect_"] {
                if label.hasPrefix(prefix) {
                    return (String(prefix.dropLast()), false)
                }
            }
            return ("opt", true)
        }

        func explicitBlockType(for label: String) -> String? {
            for marker in markers {
                if case .seqBlockType(let l, let type) = marker.kind, l == label {
                    return type
                }
            }
            return nil
        }

        func boxMetadata(for label: String) -> (fill: String, wrap: Bool, name: String)? {
            for marker in markers {
                if case .seqBox(let l, let fill, let wrap, let name) = marker.kind, l == label {
                    return (fill, wrap, name)
                }
            }
            return nil
        }

        for stmt in document.statements {
            switch stmt {
            case .nodeDefinition(let def):
                // Skip the dispatch-signal node itself
                // (`shape: sequence_diagram` at top level or as nested
                // box-marker line — for a box the box marker handles it).
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

            case .containerOpen(let open):
                if let box = boxMetadata(for: open.id) {
                    items.append(.boxStart(fill: box.fill, title: box.name, wrap: box.wrap))
                    containerStack.append(.box(label: open.id))
                } else {
                    let blockType: String
                    if let pinned = explicitBlockType(for: open.id) {
                        blockType = pinned
                    } else {
                        let inferred = inferBlockType(label: open.id)
                        blockType = inferred.type
                        if inferred.inferred {
                            diagnostics.append(.lossyTransform(
                                .styleDrop,
                                message: "D2 sequence container '\(open.id)' assumed block type 'opt'; no seq-block-type marker found"
                            ))
                        }
                    }
                    items.append(.blockStart(type: blockType, label: open.id))
                    containerStack.append(.block(label: open.id))
                }

            case .containerClose:
                guard let frame = containerStack.popLast() else { continue }
                switch frame {
                case .block(let label):
                    let resolvedType: String = {
                        for item in items.reversed() {
                            if case .blockStart(let t, let l) = item, l == label { return t }
                        }
                        return "opt"
                    }()
                    items.append(.blockEnd(type: resolvedType))
                case .box:
                    items.append(.boxEnd)
                }

            default:
                break
            }
        }

        var working = items
        applyActorKindMarkers(&working, markers: markers)
        applyArrowTypeMarkers(&working, markers: markers)
        applyBlockDividerMarkers(&working, markers: markers)

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

    /// Insert `.blockDivider` items at the message-index position
    /// indicated by each `seq-block-divider` marker. Multiple dividers
    /// for the same block land in ascending `dividerIndex` order; insert
    /// back-to-front so earlier indices stay valid.
    private func applyBlockDividerMarkers(
        _ items: inout [SequenceItem],
        markers: [RecoveryMarker<D2RecoveryMarker.Kind>]
    ) {
        struct DividerSpec {
            let containerLabel: String
            let dividerIndex: Int
            let label: String
        }
        let specs: [DividerSpec] = markers.compactMap { m in
            if case .seqBlockDivider(let label, let idx, let text) = m.kind {
                return DividerSpec(containerLabel: label, dividerIndex: idx, label: text)
            }
            return nil
        }.sorted { $0.dividerIndex > $1.dividerIndex }

        for spec in specs {
            guard let startIdx = items.firstIndex(where: {
                if case .blockStart(_, let l) = $0, l == spec.containerLabel { return true }
                return false
            }) else { continue }

            var msgsInside = 0
            var insertAt = startIdx + 1
            var depth = 1
            var cursor = startIdx + 1
            while cursor < items.count, depth > 0 {
                switch items[cursor] {
                case .blockStart:
                    depth += 1
                case .blockEnd:
                    depth -= 1
                    if depth == 0 {
                        insertAt = cursor
                        cursor = items.count
                        continue
                    }
                case .message:
                    if depth == 1 {
                        if msgsInside == spec.dividerIndex {
                            insertAt = cursor
                            cursor = items.count
                            continue
                        }
                        msgsInside += 1
                    }
                default:
                    break
                }
                cursor += 1
            }

            let blockType: String = {
                if case .blockStart(let t, _) = items[startIdx] { return t }
                return "alt"
            }()
            items.insert(.blockDivider(type: blockType, label: spec.label), at: insertAt)
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
