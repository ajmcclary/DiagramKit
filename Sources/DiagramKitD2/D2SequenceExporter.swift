import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

enum D2SequenceExport {

    static func emit(_ seq: SequenceDiagram, title: String? = nil) -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        // Dispatch signal + family marker so probes survive comment-only edits.
        lines.append("# diagramkit:family=sequence")
        lines.append("shape: sequence_diagram")
        lines.append("")

        // Title metadata first (marker + human-readable comment).
        if let t = seq.title, !t.isEmpty {
            lines.append(D2RecoveryMarker.emitSeqTitle(t))
            lines.append("# title: \(singleLine(t))")
        }
        if let t = seq.accTitle { lines.append(D2RecoveryMarker.emitSeqAccTitle(t)) }
        if let d = seq.accDescr { lines.append(D2RecoveryMarker.emitSeqAccDescr(d)) }

        // Autonumber: at most one event materializes.
        if seq.autonumberEnabled {
            lines.append(D2RecoveryMarker.emitSeqAutonumber(
                start: seq.autonumberStart,
                step: seq.autonumberStep,
                visible: true
            ))
        }

        // Actors and messages walk the canonical items timeline.
        var msgIdx = -1

        for item in seq.items {
            switch item {
            case .actor(let actor):
                let sanitizedId = sanitizeID(actor.id, &diagnostics)
                lines.append("\(sanitizedId): \"\(escape(actor.label))\"")
                if actor.type != .participant {
                    lines.append(D2RecoveryMarker.emitSeqActorKind(
                        actorID: sanitizedId,
                        participantType: actor.type.rawValue
                    ))
                    if let shape = shape(for: actor.type) {
                        lines.append("\(sanitizedId).shape: \(shape)")
                    }
                }

            case .message(let msg):
                msgIdx += 1
                let from = sanitizeID(msg.from, &diagnostics)
                let to = sanitizeID(msg.to, &diagnostics)
                let arrow = arrowToken(for: msg.arrowType)
                if msg.label.isEmpty {
                    lines.append("\(from) \(arrow) \(to)")
                } else {
                    lines.append("\(from) \(arrow) \(to): \"\(escape(msg.label))\"")
                }
                lines.append(D2RecoveryMarker.emitSeqArrowType(
                    messageIndex: msgIdx,
                    rawValue: msg.arrowType.rawValue
                ))
                if msg.activate {
                    lines.append(D2RecoveryMarker.emitSeqMessageAttr(messageIndex: msgIdx, attr: "activate"))
                }
                if msg.deactivate {
                    lines.append(D2RecoveryMarker.emitSeqMessageAttr(messageIndex: msgIdx, attr: "deactivate"))
                }
                if msg.wrap == true {
                    lines.append(D2RecoveryMarker.emitSeqMessageAttr(messageIndex: msgIdx, attr: "wrap"))
                }
                if let n = msg.sequenceNumber, msg.sequenceVisible {
                    lines.append(D2RecoveryMarker.emitSeqMessageAttr(messageIndex: msgIdx, attr: "seqNum=\(n)"))
                }

            // Block / box / note / activation / create-destroy / link items
            // are handled in later tasks.
            default:
                break
            }
        }

        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    // MARK: helpers

    static func arrowToken(for arrow: SequenceArrowType) -> String {
        switch arrow {
        case .bidirectionalSolid, .bidirectionalDotted: return "<->"
        case .dotted, .dottedCross, .dottedOpen, .dottedPoint,
             .solidArrowTopDotted, .solidArrowBottomDotted,
             .stickArrowTopDotted, .stickArrowBottomDotted,
             .solidArrowTopReverseDotted, .solidArrowBottomReverseDotted,
             .stickArrowTopReverseDotted, .stickArrowBottomReverseDotted:
            return "-->"
        default:
            return "->"
        }
    }

    static func shape(for type: ParticipantType) -> String? {
        switch type {
        case .actor:       return "person"
        case .database:    return "cylinder"
        case .queue:       return "queue"
        case .boundary:    return "oval"
        case .control:     return "hexagon"
        case .entity:      return "cloud"
        case .collections: return "page"
        case .participant: return nil
        }
    }

    static func sanitizeID(_ raw: String, _ diagnostics: inout [DiagramDiagnostic]) -> String {
        var result = ""
        var didRewrite = false
        for ch in raw {
            switch ch {
            case "a"..."z", "A"..."Z", "0"..."9", "_":
                result.append(ch)
            case " ", "-", ".":
                result.append("_")
                didRewrite = true
            default:
                result.append("_")
                didRewrite = true
            }
        }
        let safe = result.isEmpty ? "actor" : result
        if didRewrite || safe != raw {
            diagnostics.append(.lossyTransform(
                .idSanitization,
                message: "Renamed '\(raw)' → '\(safe)' for D2 ID safety"
            ))
        }
        return safe
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }

    static func singleLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .joined(separator: " ")
    }
}
