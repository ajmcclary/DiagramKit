import Foundation
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits Mermaid sequence diagram source from a `SequenceDiagram`.
enum MermaidSequenceExport {

    static func emit(_ model: SequenceDiagram) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        lines.append("sequenceDiagram")

        var emittedActorIds = Set<String>()
        // Collision-aware identifier emission for actors. Messages,
        // notes, activations, links, properties, details, and destroy
        // all reference actors; look up via `aliasMap` so collisions
        // (`foo bar` and `foo!bar` → `foo_bar` / `foo_bar_2`) resolve
        // to the right participant. Plain-sanitize fallback covers
        // references to actors that were never explicitly declared
        // (Mermaid permits lazy actor creation).
        var usedAliases: Set<String> = []
        var aliasMap: [String: String] = [:]

        for item in model.items {
            switch item {
            case .actor(let actor):
                if actor.isExplicit {
                    let (sanitizedId, idDiags) = MermaidExportHelpers.sanitizeIdentifier(
                        actor.id,
                        usedAliases: &usedAliases
                    )
                    diagnostics.append(contentsOf: idDiags)
                    aliasMap[actor.id] = sanitizedId
                    if !emittedActorIds.insert(sanitizedId).inserted {
                        // Already emitted this actor
                        continue
                    }

                    let typePrefix = actor.type.rawValue
                    if actor.label.isEmpty || actor.label == actor.id {
                        lines.append("  \(typePrefix) \(sanitizedId)")
                    } else {
                        let (label, labelDiags) = sequenceText(actor.label)
                        diagnostics.append(contentsOf: labelDiags)
                        lines.append("  \(typePrefix) \(sanitizedId) as \(label)")
                    }

                    // Links
                    for (linkLabel, url) in actor.links.sorted(by: { $0.key < $1.key }) {
                        let (ql, _) = MermaidExportHelpers.quote(linkLabel)
                        let (qu, _) = MermaidExportHelpers.quote(url)
                        lines.append("  link \(sanitizedId): \(ql) @ \(qu)")
                    }

                    // Properties
                    if !actor.properties.isEmpty {
                        let propsJSON = propertiesToJSON(actor.properties)
                        let (qj, _) = MermaidExportHelpers.quote(propsJSON)
                        lines.append("  properties \(sanitizedId): \(qj)")
                    }
                }

            case .message(let msg):
                let (sanitizedFrom, fd): (String, [DiagramDiagnostic]) = aliasMap[msg.from].map { ($0, []) }
                    ?? MermaidExportHelpers.sanitizeIdentifier(msg.from)
                let (sanitizedTo, td): (String, [DiagramDiagnostic]) = aliasMap[msg.to].map { ($0, []) }
                    ?? MermaidExportHelpers.sanitizeIdentifier(msg.to)
                diagnostics.append(contentsOf: fd)
                diagnostics.append(contentsOf: td)

                let arrow = sequenceArrow(for: msg.arrowType)
                let (escapedLabel, ld) = sequenceText(msg.label)
                diagnostics.append(contentsOf: ld)

                let msgLine = "  \(sanitizedFrom)\(arrow)\(sanitizedTo): \(escapedLabel)"
                if msg.activate {
                    lines.append("  activate \(sanitizedTo)")
                }
                lines.append(msgLine)
                if msg.deactivate {
                    lines.append("  deactivate \(sanitizedTo)")
                }

            case .note(let note):
                let actorList = note.actorIds.map { id in
                    aliasMap[id] ?? MermaidExportHelpers.sanitizeIdentifier(id).sanitized
                }.joined(separator: ", ")

                let rawPosition = note.position.isEmpty ? "over" : note.position.lowercased()
                let position = rawPosition == "left" ? "left of" : (rawPosition == "right" ? "right of" : rawPosition)
                let (qText, nd) = sequenceText(note.text)
                diagnostics.append(contentsOf: nd)

                lines.append("  Note \(position) \(actorList): \(qText)")

            case .activationStart(let actorId):
                let sanitized = aliasMap[actorId] ?? MermaidExportHelpers.sanitizeIdentifier(actorId).sanitized
                lines.append("  activate \(sanitized)")

            case .activationEnd(let actorId):
                let sanitized = aliasMap[actorId] ?? MermaidExportHelpers.sanitizeIdentifier(actorId).sanitized
                lines.append("  deactivate \(sanitized)")

            case .blockStart(let type, let label):
                if type == "rect" {
                    if label.isEmpty {
                        lines.append("  rect rgb(200, 200, 200)")
                    } else {
                        let (q, _) = sequenceText(label)
                        lines.append("  rect \(q)")
                    }
                } else {
                    if label.isEmpty {
                        lines.append("  \(type)")
                    } else {
                        let (q, _) = sequenceText(label)
                        lines.append("  \(type) \(q)")
                    }
                }

            case .blockDivider(_, let label):
                let (dividerLabel, _) = sequenceText(label)
                lines.append("  else \(dividerLabel)")

            case .blockEnd:
                lines.append("  end")

            case .boxStart(let fill, let title, _):
                if let t = title {
                    let (q, _) = sequenceText(t)
                    lines.append("  box \(q) \(fill)")
                } else {
                    lines.append("  box \(fill)")
                }

            case .boxEnd:
                lines.append("  end")

            case .autonumberEvent(let start, let step, let visible):
                if visible {
                    if start == 1 && step == 1 {
                        lines.append("  autonumber")
                    } else {
                        lines.append("  autonumber \(Int(start))")
                    }
                }

            case .createParticipant(let actor):
                let (sanitizedId, idDiags) = MermaidExportHelpers.sanitizeIdentifier(
                    actor.id,
                    usedAliases: &usedAliases
                )
                diagnostics.append(contentsOf: idDiags)
                aliasMap[actor.id] = sanitizedId
                if !emittedActorIds.insert(sanitizedId).inserted { continue }
                let typePrefix = actor.type.rawValue
                if actor.label.isEmpty || actor.label == actor.id {
                    lines.append("  create \(typePrefix) \(sanitizedId)")
                } else {
                    let (label, labelDiags) = sequenceText(actor.label)
                    diagnostics.append(contentsOf: labelDiags)
                    lines.append("  create \(typePrefix) \(sanitizedId) as \(label)")
                }

            case .destroyParticipant(let actorId):
                let sanitized = aliasMap[actorId] ?? MermaidExportHelpers.sanitizeIdentifier(actorId).sanitized
                lines.append("  destroy \(sanitized)")

            case .title(let t):
                let (q, _) = sequenceText(t)
                lines.append("  title \(q)")

            case .accTitle(let t):
                let (q, _) = sequenceText(t)
                lines.append("  accTitle: \(q)")

            case .accDescr(let d):
                let (q, _) = sequenceText(d)
                lines.append("  accDescr: \(q)")

            case .link(let actorId, let label, let url):
                let sanitized = aliasMap[actorId] ?? MermaidExportHelpers.sanitizeIdentifier(actorId).sanitized
                let (ql, _) = MermaidExportHelpers.quote(label)
                let (qu, _) = MermaidExportHelpers.quote(url)
                lines.append("  link \(sanitized): \(ql) @ \(qu)")

            case .links(let actorId, let json):
                let sanitized = aliasMap[actorId] ?? MermaidExportHelpers.sanitizeIdentifier(actorId).sanitized
                let (qj, _) = MermaidExportHelpers.quote(json)
                lines.append("  links \(sanitized): \(qj)")

            case .properties(let actorId, let json):
                let sanitized = aliasMap[actorId] ?? MermaidExportHelpers.sanitizeIdentifier(actorId).sanitized
                let (qj, _) = MermaidExportHelpers.quote(json)
                lines.append("  properties \(sanitized): \(qj)")

            case .details(let actorId, let elementId):
                let sanitized = aliasMap[actorId] ?? MermaidExportHelpers.sanitizeIdentifier(actorId).sanitized
                lines.append("  details \(sanitized): \(elementId)")
            }
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    // MARK: - Arrow conversion

    private static func sequenceArrow(for type: SequenceArrowType) -> String {
        switch type {
        case .solid: return "->>"
        case .dotted: return "-->>"
        case .solidCross: return "-x"
        case .dottedCross: return "--x"
        case .solidOpen: return "->"
        case .dottedOpen: return "-->"
        case .solidPoint: return "->>"
        case .dottedPoint: return "-->>"
        case .bidirectionalSolid: return "<<->>"
        case .bidirectionalDotted: return "<<-->>"
        case .solidArrowTop: return "->>"
        case .solidArrowBottom: return "->>"
        case .stickArrowTop: return "->>"
        case .stickArrowBottom: return "->>"
        case .solidArrowTopReverse: return "<<-"
        case .solidArrowBottomReverse: return "<<-"
        case .stickArrowTopReverse: return "<<-"
        case .stickArrowBottomReverse: return "<<-"
        case .solidArrowTopDotted: return "-->>"
        case .solidArrowBottomDotted: return "-->>"
        case .stickArrowTopDotted: return "-->>"
        case .stickArrowBottomDotted: return "-->>"
        case .solidArrowTopReverseDotted: return "<<--"
        case .solidArrowBottomReverseDotted: return "<<--"
        case .stickArrowTopReverseDotted: return "<<--"
        case .stickArrowBottomReverseDotted: return "<<--"
        }
    }

    // MARK: - Helpers

    private static func sequenceText(_ text: String) -> (escaped: String, diagnostics: [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var result = ""

        for ch in text {
            switch ch {
            case "\n":
                result += "<br/>"
                // Encoding-only: `<br/>` re-parses to a newline, so the round-trip
                // is stable. `.identifierEscape` is the closest fit in the current
                // category catalog — escape-style cosmetic that survives re-parse.
                diagnostics.append(.informational(
                    .identifierEscape,
                    message: "Newline in sequence text replaced with <br/>"
                ))
            case "\r":
                continue
            default:
                result.append(ch)
            }
        }

        return (result, diagnostics)
    }

    private static func propertiesToJSON(_ props: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: props, options: []),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
