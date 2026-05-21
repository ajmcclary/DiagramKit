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

        // Walk the canonical items timeline with stack-tracked container
        // state so blocks and boxes nest correctly and divider indices
        // are stable.
        var msgIdx = -1
        var indent = ""
        let indentUnit = "  "
        var pendingActivate = false

        struct OpenBlock { var label: String; var dividers: Int }
        var blockStack: [OpenBlock] = []
        var boxCounter = 0

        for item in seq.items {
            switch item {
            case .actor(let actor):
                let sanitizedId = sanitizeID(actor.id, &diagnostics)
                lines.append("\(indent)\(sanitizedId): \"\(escape(actor.label))\"")
                if actor.type != .participant {
                    lines.append("\(indent)\(D2RecoveryMarker.emitSeqActorKind(actorID: sanitizedId, participantType: actor.type.rawValue))")
                    if let shape = shape(for: actor.type) {
                        lines.append("\(indent)\(sanitizedId).shape: \(shape)")
                    }
                }

            case .message(let msg):
                msgIdx += 1
                let from = sanitizeID(msg.from, &diagnostics)
                let to = sanitizeID(msg.to, &diagnostics)
                let arrow = arrowToken(for: msg.arrowType)
                if msg.label.isEmpty {
                    lines.append("\(indent)\(from) \(arrow) \(to)")
                } else {
                    lines.append("\(indent)\(from) \(arrow) \(to): \"\(escape(msg.label))\"")
                }
                lines.append("\(indent)\(D2RecoveryMarker.emitSeqArrowType(messageIndex: msgIdx, rawValue: msg.arrowType.rawValue))")
                if msg.activate || pendingActivate {
                    lines.append("\(indent)\(D2RecoveryMarker.emitSeqMessageAttr(messageIndex: msgIdx, attr: "activate"))")
                }
                if msg.deactivate {
                    lines.append("\(indent)\(D2RecoveryMarker.emitSeqMessageAttr(messageIndex: msgIdx, attr: "deactivate"))")
                }
                pendingActivate = false
                if msg.wrap == true {
                    lines.append("\(indent)\(D2RecoveryMarker.emitSeqMessageAttr(messageIndex: msgIdx, attr: "wrap"))")
                }
                if let n = msg.sequenceNumber, msg.sequenceVisible {
                    lines.append("\(indent)\(D2RecoveryMarker.emitSeqMessageAttr(messageIndex: msgIdx, attr: "seqNum=\(n)"))")
                }

            case .blockStart(let type, let label):
                lines.append("\(indent)\(D2RecoveryMarker.emitSeqBlockType(containerLabel: label, blockType: type))")
                lines.append("\(indent)\(label): {")
                indent += indentUnit
                blockStack.append(OpenBlock(label: label, dividers: 0))

            case .blockDivider(_, let label):
                guard var top = blockStack.popLast() else { break }
                lines.append("\(indent)\(D2RecoveryMarker.emitSeqBlockDivider(containerLabel: top.label, dividerIndex: top.dividers + 1, label: label))")
                top.dividers += 1
                blockStack.append(top)

            case .blockEnd:
                indent = String(indent.dropLast(indentUnit.count))
                lines.append("\(indent)}")
                _ = blockStack.popLast()

            case .boxStart(let fill, let title, let wrap):
                boxCounter += 1
                let label = "box_\(boxCounter)"
                lines.append("\(indent)\(D2RecoveryMarker.emitSeqBox(containerLabel: label, fill: fill, wrap: wrap, name: title ?? label))")
                let displayTitle = title ?? label
                lines.append("\(indent)\(label): \"\(escape(displayTitle))\" {")
                indent += indentUnit
                lines.append("\(indent)shape: sequence_diagram")

            case .boxEnd:
                indent = String(indent.dropLast(indentUnit.count))
                lines.append("\(indent)}")

            case .activationStart:
                pendingActivate = true

            case .activationEnd:
                // Attach to the most recently emitted message (msgIdx).
                // If no message has been emitted yet, drop silently.
                if msgIdx >= 0 {
                    lines.append("\(indent)\(D2RecoveryMarker.emitSeqMessageAttr(messageIndex: msgIdx, attr: "deactivate"))")
                }

            case .autonumberEvent, .title, .accTitle, .accDescr:
                // Already emitted as top-level markers before the items walk.
                break

            // .note, .createParticipant, .destroyParticipant,
            // .link/.links/.properties/.details handled in Task 8.
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
