import Foundation
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits PlantUML sequence diagram source from a `SequenceDiagram`.
enum PlantUMLSequenceExport {

    static func emit(_ model: SequenceDiagram) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        lines.append("@startuml")

        var emittedActorIds = Set<String>()

        for item in model.items {
            switch item {
            case .actor(let actor):
                if actor.isExplicit {
                    let actorAlias = participantAlias(actor.id)
                    if !emittedActorIds.insert(actorAlias).inserted { continue }

                    let typeStr = plantUMLParticipantType(actor.type)

                    if actor.id == actor.label || actor.label.isEmpty {
                        lines.append("\(typeStr) \(actorAlias)")
                    } else {
                        lines.append("\(typeStr) \(quoted(actor.label)) as \(actorAlias)")
                    }
                }

            case .message(let msg):
                let from = participantAlias(msg.from)
                let to = participantAlias(msg.to)
                let arrow = plantUMLArrow(for: msg.arrowType)

                if msg.activate {
                    lines.append("activate \(to)")
                }
                // Route through the shared `escape()` helper so messages
                // with backslashes or double quotes are emitted as valid
                // PlantUML. Previously only `\n` was escaped, leaving the
                // line vulnerable to corruption when labels contained
                // `\` or `"`.
                lines.append("\(from) \(arrow) \(to): \(escapeFreeText(msg.label))")
                if msg.deactivate {
                    lines.append("deactivate \(to)")
                }

            case .note(let note):
                let actorList = note.actorIds.map { participantAlias($0) }.joined(separator: ", ")
                let rawPosition = note.position.isEmpty ? "over" : note.position.lowercased()
                let position = rawPosition == "left" ? "left of" : (rawPosition == "right" ? "right of" : rawPosition)
                let text = escapeFreeText(note.text)
                lines.append("note \(position) \(actorList): \(text)")

            case .activationStart(let actorId):
                lines.append("activate \(participantAlias(actorId))")

            case .activationEnd(let actorId):
                lines.append("deactivate \(participantAlias(actorId))")

            case .blockStart(let type, let label):
                if type == "rect" {
                    if label.isEmpty {
                        lines.append("group")
                    } else {
                        lines.append("group \(escapeFreeText(label))")
                    }
                } else {
                    if label.isEmpty {
                        lines.append("\(type)")
                    } else {
                        lines.append("\(type) \(escapeFreeText(label))")
                    }
                }

            case .blockDivider(_, let label):
                lines.append("else \(escapeFreeText(label))")

            case .blockEnd:
                lines.append("end")

            case .boxStart(let fill, let title, _):
                let normalizedFill = normalizeColor(fill)
                if let t = title {
                    lines.append("box \(quoted(t)) \(normalizedFill)")
                } else {
                    lines.append("box \(normalizedFill)")
                }

            case .boxEnd:
                lines.append("end box")

            case .autonumberEvent(_, _, let visible):
                if visible {
                    // Bare form — the one `PlantUMLSequenceParser` accepts.
                    // Start/step are PlantUML's 1/1 defaults on re-import.
                    lines.append("autonumber")
                }

            case .title(let t):
                lines.append("title \(escapeFreeText(t))")

            case .accTitle, .accDescr:
                // PlantUML doesn't have accTitle/accDescr equivalents
                break

            case .createParticipant(let actor):
                let actorAlias = participantAlias(actor.id)
                if !emittedActorIds.insert(actorAlias).inserted { continue }
                let typeStr = plantUMLParticipantType(actor.type)
                if actor.id == actor.label || actor.label.isEmpty {
                    lines.append("\(typeStr) \(actorAlias)")
                } else {
                    lines.append("\(typeStr) \(quoted(actor.label)) as \(actorAlias)")
                }

            case .destroyParticipant(let actorId):
                lines.append("destroy \(participantAlias(actorId))")

            case .link(let actorId, let label, let url):
                lines.append(PlantUMLRecoveryMarker.emitSequenceParticipantLink(
                    participantId: actorId, label: label, url: url
                ))

            case .links(let actorId, let json):
                lines.append(PlantUMLRecoveryMarker.emitSequenceParticipantLinks(
                    participantId: actorId, json: json
                ))

            case .properties(let actorId, let json):
                lines.append(PlantUMLRecoveryMarker.emitSequenceParticipantProperties(
                    participantId: actorId, json: json
                ))

            case .details(let actorId, let elementId):
                lines.append(PlantUMLRecoveryMarker.emitSequenceParticipantDetails(
                    participantId: actorId, elementId: elementId
                ))
            }
        }

        lines.append("@enduml")

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    // MARK: - Helpers

    private static func plantUMLParticipantType(_ type: ParticipantType) -> String {
        switch type {
        case .participant: return "participant"
        case .actor: return "actor"
        case .boundary: return "boundary"
        case .control: return "control"
        case .entity: return "entity"
        case .database: return "database"
        case .collections: return "collections"
        case .queue: return "queue"
        }
    }

    private static func plantUMLArrow(for type: SequenceArrowType) -> String {
        switch type {
        case .solid, .solidArrowTop, .solidArrowBottom: return "->"
        case .dotted, .solidArrowTopDotted, .solidArrowBottomDotted: return "-->"
        case .solidCross: return "->x"
        case .dottedCross: return "--x"
        case .solidOpen: return "->"
        case .dottedOpen: return "-->"
        case .solidPoint: return "->"
        case .dottedPoint: return "-->"
        case .bidirectionalSolid: return "<->"
        case .bidirectionalDotted: return "<-->"
        case .stickArrowTop, .stickArrowBottom: return "->"
        case .solidArrowTopReverse, .solidArrowBottomReverse: return "<-"
        case .stickArrowTopReverse, .stickArrowBottomReverse: return "<-"
        case .stickArrowTopDotted, .stickArrowBottomDotted: return "-->"
        case .solidArrowTopReverseDotted, .solidArrowBottomReverseDotted: return "<--"
        case .stickArrowTopReverseDotted, .stickArrowBottomReverseDotted: return "<--"
        }
    }

    private static func participantAlias(_ text: String) -> String {
        let simplePattern = #"^[A-Za-z_][A-Za-z0-9_]*$"#
        if text.range(of: simplePattern, options: .regularExpression) != nil {
            return text
        }
        return quoted(text)
    }

    private static func quoted(_ text: String) -> String {
        "\"\(PlantUMLHygiene.escapeSequenceString(text))\""
    }

    private static func normalizeColor(_ color: String) -> String {
        color.hasPrefix("#") ? color : "#\(color)"
    }

    /// Free text after `:` / in block headers: only newlines need
    /// collapsing — PlantUML renders `\"` literally (no escape processing),
    /// so backslash-escaping quotes corrupted round-tripped labels.
    private static func escapeFreeText(_ text: String) -> String {
        PlantUMLHygiene.escapeSequenceFreeText(text)
    }

    private static func escape(_ text: String) -> String {
        // Multiline title/note/group/box/else labels must collapse into
        // PlantUML's inline-newline escape (`\n` in source) — otherwise the
        // line-oriented @startuml/@enduml model gets corrupt extra lines.
        PlantUMLHygiene.escapeSequenceString(text)
    }
}
