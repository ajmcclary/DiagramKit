import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid sequence diagram source from a `SequenceDiagram`.
///
/// A canvas edit saves this output as the document, so it writes every
/// item back in the form the parser reads into the same item: parse →
/// export → parse gives back the same timeline (`SequenceExportFidelityTests`).
/// Statement order is the model's item order.
enum MermaidSequenceExport {

    static func emit(_ model: SequenceDiagram) throws -> DiagramExportResult {
        var emitter = Emitter(items: model.items)
        emitter.run()
        let source = emitter.lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: emitter.diagnostics)
    }

    // MARK: - Emitter

    private struct Emitter {
        let items: [SequenceItem]
        var lines: [String] = ["sequenceDiagram"]
        var diagnostics: [DiagramDiagnostic] = []
        /// Actor ids the parser knows when it reaches the current item.
        var known: Set<String> = []
        /// Ids that cannot be written as they are, and what they became.
        var renamed: [String: String] = [:]
        var usedAliases: Set<String> = []
        /// Types of the open `box` / block statements, for divider keywords.
        var open: [String] = []

        init(items: [SequenceItem]) {
            self.items = items
        }

        mutating func run() {
            var index = 0
            while index < items.count {
                index = emit(at: index)
            }
        }

        /// Emits the item at `index` (and any it owns); returns the next index.
        mutating func emit(at index: Int) -> Int {
            switch items[index] {
            case .actor(let actor):
                if actor.isExplicit {
                    lines.append("  " + declaration(actor))
                    known.insert(actor.id)
                    return index + 1
                }
                return implicitRun(from: index)

            case .createParticipant(let actor):
                let keyword = actor.type == .actor ? "actor" : "participant"
                if actor.type != .actor && actor.type != .participant {
                    lossy("create statements take participant or actor; '\(actor.id)' is written as participant")
                }
                let id = ref(actor.id)
                let alias = actor.label.isEmpty || actor.label == actor.id ? "" : " as \(escaped(actor.label))"
                lines.append("  create \(keyword) \(id)\(alias)")
                known.insert(actor.id)

            case .message(let message):
                // `A->>+B` is read as an activation item then the message;
                // a flag without that item (another format's model) is
                // written as its own statement.
                var attached = false
                if index > 0, case .activationStart(let id) = items[index - 1], message.activate, id == message.to {
                    attached = true
                } else if index > 0, case .activationEnd(let id) = items[index - 1], message.deactivate, !message.activate, id == message.from {
                    attached = true
                } else if message.activate {
                    lines.append("  activate \(ref(message.to))")
                } else if message.deactivate {
                    lines.append("  deactivate \(ref(message.from))")
                }
                lines.append("  " + messageLine(message, marker: attached))

            case .activationStart(let actorId):
                // `A->>+B` puts this item directly before its message.
                if index + 1 < items.count, case .message(let m) = items[index + 1], m.activate, m.to == actorId {
                    return index + 1
                }
                lines.append("  activate \(ref(actorId))")

            case .activationEnd(let actorId):
                if index + 1 < items.count, case .message(let m) = items[index + 1], m.deactivate, !m.activate, m.from == actorId {
                    return index + 1
                }
                lines.append("  deactivate \(ref(actorId))")

            case .note(let note):
                let position: String
                switch note.position.lowercased() {
                case "left": position = "left of"
                case "right": position = "right of"
                default: position = "over"
                }
                var text = escaped(note.text)
                if text.isEmpty {
                    lossy("a note needs text; an empty note is written with a single space")
                    text = "#32;"
                }
                var actors: [String] = []
                for id in note.actorIds { actors.append(ref(id)) }
                lines.append("  Note \(position) \(actors.joined(separator: ", ")): \(text)")

            case .blockStart(let type, let label):
                open.append(type)
                lines.append("  " + (label.isEmpty ? type : "\(type) \(escaped(label))"))

            case .blockDivider(let type, let label):
                let keyword: String
                switch open.last ?? type {
                case "par", "par_over": keyword = "and"
                case "critical": keyword = "option"
                default: keyword = "else"
                }
                lines.append("  " + (label.isEmpty ? keyword : "\(keyword) \(escaped(label))"))

            case .blockEnd, .boxEnd:
                _ = open.popLast()
                lines.append("  end")

            case .boxStart(let fill, let title, _):
                open.append("box")
                if let title, !title.isEmpty {
                    lines.append("  box \(fill) \(escaped(title))")
                } else {
                    lines.append("  box \(fill)")
                }

            case .autonumberEvent(let start, let step, let visible):
                if !visible {
                    lines.append("  autonumber off")
                } else if start == 1 && step == 1 {
                    lines.append("  autonumber")
                } else if step == 1 {
                    lines.append("  autonumber \(number(start))")
                } else {
                    lines.append("  autonumber \(number(start)) \(number(step))")
                }

            case .destroyParticipant(let actorId):
                lines.append("  destroy \(ref(actorId))")

            case .title(let text):
                lines.append("  title \(escaped(text))")

            case .accTitle(let text):
                lines.append("  accTitle: \(escaped(text))")

            case .accDescr(let text):
                if text.contains("\n") {
                    lines.append("  accDescr {")
                    lines += text.split(separator: "\n", omittingEmptySubsequences: false).map { "    " + escaped(String($0)) }
                    lines.append("  }")
                } else {
                    lines.append("  accDescr: \(escaped(text))")
                }

            case .link(let actorId, let label, let url):
                if label.contains("@") { lossy("a link label containing '@' cannot be written; the URL starts at its first '@'") }
                lines.append("  link \(ref(actorId)): \(escaped(label)) @ \(escaped(url))")

            case .links(let actorId, let json):
                lines.append("  links \(ref(actorId)): \(escaped(json))")

            case .properties(let actorId, let json):
                lines.append("  properties \(ref(actorId)): \(escaped(json))")

            case .details(let actorId, let elementId):
                lines.append("  details \(ref(actorId)): \(escaped(elementId))")
            }
            return index + 1
        }

        // MARK: Actors

        /// A run of implicit actor items. The parser creates them itself, in
        /// this order, right before the message that first names them; when
        /// the run is exactly that, nothing is written. Otherwise (a canvas
        /// move changed which message comes first) they are declared, so the
        /// participant order stays.
        mutating func implicitRun(from start: Int) -> Int {
            var end = start
            var run: [SequenceActor] = []
            while end < items.count, case .actor(let a) = items[end], !a.isExplicit {
                run.append(a)
                end += 1
            }
            var messageIndex = end
            if messageIndex < items.count {
                switch items[messageIndex] {
                case .activationStart, .activationEnd: messageIndex += 1
                default: break
                }
            }
            var expected: [String] = []
            if messageIndex < items.count, case .message(let m) = items[messageIndex] {
                if !known.contains(m.from) { expected.append(m.from) }
                if !known.contains(m.to), m.to != m.from { expected.append(m.to) }
            }
            let fresh = run.filter { !known.contains($0.id) }
            if fresh.map(\.id) != expected {
                for actor in fresh { lines.append("  " + declaration(actor)) }
            }
            for actor in fresh { known.insert(actor.id) }
            return end
        }

        mutating func declaration(_ actor: SequenceActor) -> String {
            let id = ref(actor.id)
            let standard: Set<ParticipantType> = [.participant, .actor]
            let configType = actor.config?.type ?? (standard.contains(actor.type) ? nil : actor.type)
            if actor.config != nil || configType != nil {
                var parts: [String] = []
                if let configType { parts.append("\"type\": \"\(configType.rawValue)\"") }
                if let alias = actor.config?.alias {
                    if alias.contains("\"") || alias.contains("}") { lossy("participant alias '\(alias)' cannot be written inside @{…}") }
                    parts.append("\"alias\": \"\(alias)\"")
                }
                let keyword = actor.type == .actor && configType == nil ? "actor" : "participant"
                var text = "\(keyword) \(id)@{ \(parts.joined(separator: ", ")) }"
                if actor.label != (actor.config?.alias ?? actor.id) {
                    text += " as \(escaped(actor.label))"
                }
                if actor.wrap != nil { lossy("text wrapping on participant '\(actor.id)' cannot be written next to @{…}") }
                return text
            }
            let keyword = actor.type == .actor ? "actor" : "participant"
            let wrap = actor.wrap.map { $0 ? "wrap:" : "nowrap:" } ?? ""
            if wrap.isEmpty && actor.label == actor.id {
                return "\(keyword) \(id)"
            }
            return "\(keyword) \(id) as \(wrap)\(escaped(actor.label))"
        }

        /// The id as written. An id the parser would read differently is
        /// renamed once, with a diagnostic, and every reference follows.
        mutating func ref(_ id: String) -> String {
            if let name = renamed[id] { return name }
            if Self.representable(id) {
                renamed[id] = id
                usedAliases.insert(id)
                return id
            }
            let (name, diags) = MermaidExportHelpers.sanitizeIdentifier(id, usedAliases: &usedAliases)
            diagnostics += diags
            renamed[id] = name
            return name
        }

        static func representable(_ id: String) -> Bool {
            guard !id.isEmpty, id.trimmingCharacters(in: .whitespaces) == id else { return false }
            if id.contains(where: { "<>:,;@#\n\r\"".contains($0) }) { return false }
            if id.contains("%%") || id.lowercased().contains(" as ") { return false }
            if id.hasPrefix("+") || id.hasPrefix("-") || id.hasSuffix("+") || id.hasSuffix("-") { return false }
            if id.hasPrefix("()") || id.hasSuffix("()") { return false }
            let lower = id.lowercased()
            let keywords = ["participant", "actor", "note", "loop", "alt", "opt", "par", "par_over", "critical",
                            "break", "rect", "else", "and", "option", "end", "box", "create", "destroy", "activate",
                            "deactivate", "link", "links", "properties", "details", "autonumber", "title", "accTitle",
                            "accDescr"]
            // A statement keyword then a space starts that statement instead.
            if keywords.contains(where: { lower.hasPrefix($0.lowercased() + " ") || lower.hasPrefix($0.lowercased() + "\t") }) { return false }
            return !arrowTable.contains { id.contains($0.pattern) }
        }

        // MARK: Messages

        mutating func messageLine(_ message: SequenceMessage, marker attached: Bool) -> String {
            var from = ref(message.from)
            var to = ref(message.to)
            let arrow = Self.arrowText(message.arrowType)
            let central = message.centralConnection
            let source = central == .source || central == .both ? "()" : ""
            let dest = central == .dest || central == .both ? "()" : ""
            let marker = !attached ? "" : (message.activate ? "+" : "-")
            if message.activate && message.deactivate {
                lossy("a message both activating and deactivating cannot be written; it keeps the activation")
            }
            if !Self.parsesBack(from: from + source, arrow: message.arrowType, rest: dest + marker + to) {
                // Defensive: an id that survives `representable` but still
                // fuses with the arrow. Rename both ends.
                from = forceRename(message.from)
                to = forceRename(message.to)
            }
            if message.wrap != nil {
                lossy("text wrapping on a message cannot be written back")
            }
            return "\(from)\(source)\(arrow)\(dest)\(marker)\(to): \(escaped(message.label))"
        }

        mutating func forceRename(_ id: String) -> String {
            let (name, diags) = MermaidExportHelpers.sanitizeIdentifier(id, usedAliases: &usedAliases)
            diagnostics += diags
            renamed[id] = name
            return name
        }

        /// Whether the parser's arrow scan (longest pattern first, first
        /// occurrence) finds `arrow` right after `from`.
        static func parsesBack(from: String, arrow: SequenceArrowType, rest: String) -> Bool {
            let line = from + arrowText(arrow) + rest
            for (pattern, type) in arrowTable {
                guard let range = line.range(of: pattern) else { continue }
                return type == arrow && line.distance(from: line.startIndex, to: range.lowerBound) == from.count
            }
            return false
        }

        static func arrowText(_ type: SequenceArrowType) -> String {
            arrowTable.first { $0.type == type }?.pattern ?? "->>"
        }

        /// The parser's arrow table, in its order (`src_sequence_parser`).
        static let arrowTable: [(pattern: String, type: SequenceArrowType)] = [
            ("<<-->>", .bidirectionalDotted),
            ("<<->>", .bidirectionalSolid),
            ("--|\\", .solidArrowTopDotted),
            ("--|/", .solidArrowBottomDotted),
            ("--\\\\", .stickArrowTopDotted),
            ("--//", .stickArrowBottomDotted),
            ("/|--", .solidArrowTopReverseDotted),
            ("\\|--", .solidArrowBottomReverseDotted),
            ("//--", .stickArrowTopReverseDotted),
            ("\\\\--", .stickArrowBottomReverseDotted),
            ("-->>", .dotted),
            ("--x", .dottedCross),
            ("--)", .dottedPoint),
            ("-->", .dottedOpen),
            ("-|\\", .solidArrowTop),
            ("-|/", .solidArrowBottom),
            ("-\\\\", .stickArrowTop),
            ("-//", .stickArrowBottom),
            ("/\\|-", .solidArrowTopReverse),
            ("\\|-", .solidArrowBottomReverse),
            ("//-", .stickArrowTopReverse),
            ("\\\\-", .stickArrowBottomReverse),
            ("->>", .solid),
            ("-x", .solidCross),
            ("-)", .solidPoint),
            ("->", .solidOpen),
        ]

        // MARK: Text

        /// Text as written in a statement. The importer decodes entity codes
        /// in every sequence string after parsing, so `#`, `;` and `%%`,
        /// which would start a comment or end the statement, are written as
        /// codes, as is the `<` of a literal `<br`; a newline is `<br/>`.
        func escaped(_ text: String) -> String {
            var out = ""
            var previous: Character?
            let chars = Array(text)
            for (i, ch) in chars.enumerated() {
                switch ch {
                case "\n": out += "<br/>"
                case "\r": break
                case "#": out += "#35;"
                case ";": out += "#59;"
                case "%" where previous == "%" || (i + 1 < chars.count && chars[i + 1] == "%"):
                    out += "#37;"
                case "<" where i + 2 < chars.count && chars[i + 1].lowercased() == "b" && chars[i + 2].lowercased() == "r":
                    out += "#lt;"
                default: out.append(ch)
                }
                previous = ch
            }
            return out
        }

        mutating func number(_ value: Double) -> String {
            if value.rounded() == value, abs(value) < 1e15 { return _integralText(value) }
            let text = String(format: "%.2f", value)
            if Double(text) != value { lossy("autonumber value \(value) is written with two decimals") }
            return text
        }

        mutating func lossy(_ message: String) {
            diagnostics.append(MermaidExportDiagnostics.unsupportedFeature("sequence", detail: message))
        }
    }
}
