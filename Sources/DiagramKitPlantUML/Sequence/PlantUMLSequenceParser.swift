import Foundation
import DiagramKitImport

/// Line-based parser for PlantUML sequence diagram bodies.
///
/// Operates on the body text between `@startuml` and `@enduml`.
/// Parses participants, messages, activations, notes, grouping
/// constructs, and emits diagnostics for unsupported syntax.
public struct PlantUMLSequenceParser {
    public init() {}

    public func parse(_ body: String) -> PlantUMLSequenceAST {
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
        var participants: [PlantUMLParticipant] = []
        var items: [PlantUMLSequenceItem] = []
        var hasAutoNumber = false

        // First pass: collect participant/actor declarations
        var lineNumber = 0
        var participantAliases = Set<String>()
        var currentBoxName: String?
        var currentBoxFill: String?

        for line in lines {
            lineNumber += 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.lowercased()

            if lower.hasPrefix("box ") {
                let box = _parseBoxContext(trimmed)
                currentBoxName = box.title
                currentBoxFill = box.fill
                continue
            }

            if lower == "end box" || lower == "endbox" {
                currentBoxName = nil
                currentBoxFill = nil
                continue
            }

            if let p = _parseParticipant(trimmed, boxName: currentBoxName, boxFill: currentBoxFill) {
                if !participantAliases.contains(p.alias) {
                    participants.append(p)
                    participantAliases.insert(p.alias)
                }
            }
        }

        // Second pass: walk lines and emit items
        lineNumber = 0
        var lastMessage: PlantUMLSequenceMessage?
        var i = 0
        while i < lines.count {
            lineNumber += 1
            let rawLine = lines[i]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            defer { i += 1 }

            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.lowercased()

            // Skip participant/actor declarations (already collected)
            if lower.hasPrefix("participant ") || lower.hasPrefix("actor ") {
                continue
            }

            if lower.hasPrefix("box ") || lower == "end box" || lower == "endbox" {
                continue
            }

            // Auto-number
            if lower == "autonumber" {
                items.append(.autoNumberStart)
                hasAutoNumber = true
                continue
            }
            if lower == "autonumber stop" {
                items.append(.autoNumberStop)
                continue
            }

            // Activations
            if lower.hasPrefix("activate ") {
                let target = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                items.append(.activate(target))
                continue
            }
            if lower == "activate" {
                if let target = lastMessage?.to {
                    items.append(.activate(target))
                } else {
                    items.append(.unsupported("activate without previous message", line: lineNumber))
                }
                continue
            }
            if lower.hasPrefix("deactivate ") {
                let target = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespaces)
                items.append(.deactivate(target))
                continue
            }
            if lower == "deactivate" {
                if let target = lastMessage?.from {
                    items.append(.deactivate(target))
                } else {
                    items.append(.unsupported("deactivate without previous message", line: lineNumber))
                }
                continue
            }

            // Notes
            if lower.hasPrefix("note ") {
                if let note = _parseNote(trimmed, lineNumber: lineNumber) {
                    items.append(note)
                }
                continue
            }

            // Grouping constructs: alt, loop, opt, group
            if lower.hasPrefix("alt ") {
                let label = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                items.append(.groupStart(label, kind: .alt))
                continue
            }
            if lower.hasPrefix("loop ") {
                let label = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                items.append(.groupStart(label, kind: .loop))
                continue
            }
            if lower.hasPrefix("opt ") {
                let label = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                items.append(.groupStart(label, kind: .opt))
                continue
            }
            if lower.hasPrefix("group ") {
                let label = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                items.append(.groupStart(label, kind: .group))
                continue
            }

            // Else
            if lower.hasPrefix("else ") {
                let label = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                items.append(.divergent(label))
                continue
            }
            if lower == "else" {
                items.append(.divergent(""))
                continue
            }

            // End
            if lower == "end" {
                items.append(.groupEnd)
                continue
            }

            // Return keyword (--> with implicit deactivate)
            if lower == "return" || lower.hasPrefix("return ") {
                let rest = lower == "return" ? "" : String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                if let msg = _parseReturnMessage(rest, previousMessage: lastMessage) {
                    items.append(.message(msg))
                    lastMessage = msg
                } else {
                    items.append(.unsupported("return without previous message", line: lineNumber))
                }
                continue
            }

            // Messages (arrows)
            if let msg = _parseSequenceMessage(trimmed, lineNumber: lineNumber) {
                // Track any undeclared participants
                if !participantAliases.contains(msg.from) {
                    participants.append(PlantUMLParticipant(
                        kind: .participant,
                        alias: msg.from,
                        displayName: msg.from
                    ))
                    participantAliases.insert(msg.from)
                }
                if !participantAliases.contains(msg.to) {
                    participants.append(PlantUMLParticipant(
                        kind: .participant,
                        alias: msg.to,
                        displayName: msg.to
                    ))
                    participantAliases.insert(msg.to)
                }
                items.append(.message(msg))
                lastMessage = msg
                continue
            }

            // Unsupported constructs — emit diagnostics
            let unsupported = _detectUnsupported(trimmed, lineNumber: lineNumber)
            if let unsup = unsupported {
                items.append(unsup)
                continue
            }

            // Lines we don't recognize — pass through as unsupported
            if !trimmed.isEmpty && !trimmed.hasPrefix("'") && !trimmed.hasPrefix("!") {
                items.append(.unsupported("unrecognized syntax: \(trimmed.prefix(40))", line: lineNumber))
            }
        }

        return PlantUMLSequenceAST(
            participants: participants,
            items: items,
            hasAutoNumber: hasAutoNumber
        )
    }

    // MARK: - Participant parsing

    private func _parseParticipant(_ line: String, boxName: String?, boxFill: String?) -> PlantUMLParticipant? {
        let lower = line.lowercased()
        let kind: PlantUMLParticipantKind
        let rest: String

        if lower.hasPrefix("participant ") {
            kind = .participant
            rest = String(line.dropFirst(12)).trimmingCharacters(in: .whitespaces)
        } else if lower.hasPrefix("actor ") {
            kind = .actor
            rest = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else {
            return nil
        }

        guard !rest.isEmpty else { return nil }

        // Parse: Name or "Display Name" as Alias or "Display Name" as "Alias"
        var displayName: String? = nil
        var alias: String = ""
        var remaining = rest

        // First token could be quoted or unquoted
        if remaining.hasPrefix("\"") {
            if let endQuote = _findClosingQuote(in: remaining, start: remaining.index(after: remaining.startIndex)) {
                displayName = String(remaining[remaining.index(after: remaining.startIndex)..<endQuote])
                remaining = String(remaining[remaining.index(after: endQuote)...]).trimmingCharacters(in: .whitespaces)
            }
        } else {
            // Unquoted name
            let tokens = remaining.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if let first = tokens.first {
                let name = String(first)
                remaining = tokens.count > 1 ? String(tokens[1]) : ""
                // If "as" follows, this is the display name, not alias
                if remaining.lowercased().hasPrefix("as ") {
                    displayName = name
                } else {
                    alias = name
                    // If there's more text, it could be "as Alias" 
                    let trimmedRemaining = remaining.trimmingCharacters(in: .whitespaces)
                    if trimmedRemaining.lowercased().hasPrefix("as ") {
                        let aliasPart = String(trimmedRemaining.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                        displayName = name
                        alias = aliasPart.hasPrefix("\"")
                            ? _stripQuotes(aliasPart)
                            : String(aliasPart.split(separator: " ").first ?? Substring(aliasPart))
                    }
                    return PlantUMLParticipant(
                        kind: kind,
                        alias: alias,
                        displayName: displayName,
                        boxName: boxName,
                        boxFill: boxFill
                    )
                }
            }
        }

        // After the display name, look for "as Alias"
        if remaining.lowercased().hasPrefix("as ") {
            let aliasPart = String(remaining.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            alias = _stripQuotes(aliasPart)
        } else if alias.isEmpty, let dn = displayName {
            alias = dn.replacingOccurrences(of: " ", with: "")
        }

        guard !alias.isEmpty else { return nil }
        return PlantUMLParticipant(
            kind: kind,
            alias: alias,
            displayName: displayName,
            boxName: boxName,
            boxFill: boxFill
        )
    }

    // MARK: - Message parsing

    private func _parseSequenceMessage(_ line: String, lineNumber: Int) -> PlantUMLSequenceMessage? {
        // Find the arrow in the line
        // Patterns: A -> B : label, A --> B : label, A ->> B : label, etc.
        // Also handle reverse: A <- B, A <-- B

        // First, try to find the colon separator (label)
        var labelPart: String? = nil
        var arrowPart = line
        if let colonIdx = line.firstIndex(of: ":") {
            // Make sure this isn't inside a quoted string
            labelPart = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            arrowPart = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces)
        }

        // Detect arrow type and direction
        let arrowPairs: [(String, PlantUMLArrowType, Bool)] = [
            ("-->", .dotted, false),
            ("->>", .open, false),
            ("->o", .circle, false),
            ("->x", .cross, false),
            ("<->", .bidirectional, false),
            ("->", .solid, false),
            ("<--", .dotted, true),
            ("<<-", .open, true),
            ("<-", .solid, true),
        ]

        for (arrowStr, arrowType, isReverse) in arrowPairs {
            if let arrowRange = arrowPart.range(of: arrowStr) {
                let fromStr = String(arrowPart[..<arrowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let toStr = String(arrowPart[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)

                guard !fromStr.isEmpty && !toStr.isEmpty else { continue }

                let from = _stripQuotes(fromStr)
                let to = _stripQuotes(toStr)

                if isReverse {
                    return PlantUMLSequenceMessage(from: to, to: from, arrow: arrowType, label: labelPart)
                }
                return PlantUMLSequenceMessage(from: from, to: to, arrow: arrowType, label: labelPart)
            }
        }

        return nil
    }

    private func _parseReturnMessage(_ rest: String, previousMessage: PlantUMLSequenceMessage?) -> PlantUMLSequenceMessage? {
        guard let previousMessage else { return nil }
        return PlantUMLSequenceMessage(
            from: previousMessage.to,
            to: previousMessage.from,
            arrow: .dotted,
            label: rest,
            deactivate: true
        )
    }

    // MARK: - Note parsing

    private func _parseNote(_ line: String, lineNumber: Int) -> PlantUMLSequenceItem? {
        let lower = line.lowercased()
        // note left of X: text
        // note right of X: text
        // note over X, Y: text
        // note over X: text

        var position: PlantUMLNotePosition = .over
        var rest: String

        if lower.hasPrefix("note left of ") {
            position = .left
            rest = String(line.dropFirst(13)).trimmingCharacters(in: .whitespaces)
        } else if lower.hasPrefix("note right of ") {
            position = .right
            rest = String(line.dropFirst(14)).trimmingCharacters(in: .whitespaces)
        } else if lower.hasPrefix("note over ") {
            position = .over
            rest = String(line.dropFirst(10)).trimmingCharacters(in: .whitespaces)
        } else {
            return .unsupported("unrecognized note syntax", line: lineNumber)
        }

        // Parse targets then text: `X, Y : text` or `X : text`
        var targets: [String] = []
        if let colonIdx = rest.firstIndex(of: ":") {
            let targetStr = String(rest[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            targets = targetStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            rest = String(rest[rest.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
        } else {
            // No colon — the whole thing might be a target or unrecognized
            return .unsupported("note without text separator ':'", line: lineNumber)
        }

        guard !targets.isEmpty else {
            return .unsupported("note without target participant", line: lineNumber)
        }

        return .note(PlantUMLSequenceNote(
            position: position,
            targets: targets,
            text: rest
        ))
    }

    // MARK: - Unsupported detection

    private func _detectUnsupported(_ line: String, lineNumber: Int) -> PlantUMLSequenceItem? {
        let lower = line.lowercased()

        if lower.hasPrefix("newpage") {
            return .unsupported("PlantUML newpage is not supported", line: lineNumber)
        }
        if lower.hasPrefix("title ") {
            return .unsupported("PlantUML title is not supported", line: lineNumber)
        }
        if lower.hasPrefix("footer ") || lower.hasPrefix("header ") {
            return .unsupported("PlantUML footer/header not supported", line: lineNumber)
        }
        if lower.hasPrefix("skinparam ") {
            return .unsupported("PlantUML skinparam styling not supported", line: lineNumber)
        }
        if lower.hasPrefix("hnote ") || lower.hasPrefix("rnote ") {
            return .unsupported("PlantUML hnote/rnote not supported", line: lineNumber)
        }
        if lower.hasPrefix("create ") || lower.hasPrefix("destroy ") {
            return .unsupported("PlantUML create/destroy not supported", line: lineNumber)
        }
        if lower.hasPrefix("ref over ") {
            return .unsupported("PlantUML ref over not supported", line: lineNumber)
        }
        if lower.contains("<<") && lower.contains(">>") {
            return .unsupported("PlantUML stereotypes not supported", line: lineNumber)
        }
        if lower.contains("||") {
            return .unsupported("PlantUML separator lines not supported", line: lineNumber)
        }

        return nil
    }

    // MARK: - Helpers

    private func _findClosingQuote(in str: String, start: String.Index) -> String.Index? {
        var idx = start
        while idx < str.endIndex {
            if str[idx] == "\"" && (idx == str.startIndex || str[str.index(before: idx)] != "\\") {
                return idx
            }
            idx = str.index(after: idx)
        }
        return nil
    }

    private func _stripQuotes(_ str: String) -> String {
        if str.hasPrefix("\"") && str.hasSuffix("\"") && str.count >= 2 {
            return String(str.dropFirst().dropLast())
        }
        return str
    }

    private func _parseBoxContext(_ line: String) -> (title: String?, fill: String?) {
        var rest = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        var title: String?
        var fill: String?

        if rest.hasPrefix("\""),
           let endQuote = _findClosingQuote(in: rest, start: rest.index(after: rest.startIndex)) {
            title = String(rest[rest.index(after: rest.startIndex)..<endQuote])
            rest = String(rest[rest.index(after: endQuote)...]).trimmingCharacters(in: .whitespaces)
        } else if !rest.isEmpty {
            let parts = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if let first = parts.first {
                let firstToken = String(first)
                if firstToken.hasPrefix("#") {
                    fill = _normalizePlantUMLColor(firstToken)
                } else {
                    title = firstToken
                }
                rest = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : ""
            }
        }

        if !rest.isEmpty {
            let parts = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if let first = parts.first, first.hasPrefix("#") {
                fill = _normalizePlantUMLColor(String(first))
            }
        }

        return (title: title, fill: fill)
    }

    private func _normalizePlantUMLColor(_ color: String) -> String {
        guard color.hasPrefix("#") else { return color }
        let value = String(color.dropFirst())
        if value.range(of: #"^[0-9A-Fa-f]{3}([0-9A-Fa-f]{3})?([0-9A-Fa-f]{2})?$"#, options: .regularExpression) != nil {
            return color
        }
        return value
    }
}
