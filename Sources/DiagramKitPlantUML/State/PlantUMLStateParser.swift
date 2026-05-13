import Foundation
import DiagramKitImport

/// Line-based parser for PlantUML state and activity diagram bodies.
///
/// Recognizes:
///   - `state Name` / `state Name : description` / `state "Display" as Alias`
///   - `state Composite { … }` (composite states; recurses)
///   - `[*] --> A`, `A --> [*]`, `A --> B : label` (state transitions)
///   - `start`, `stop`, `:action;` (activity short-form; collapses into
///     pseudostate-style transitions)
///   - `note left of A : text`
///
/// Anything unrecognized is collected as an unsupported line so the
/// importer can surface diagnostics.
public struct PlantUMLStateParser {

    public init() {}

    public func parse(_ body: String) -> PlantUMLStateAST {
        var lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0
        return parseBlock(lines: &lines, index: &index, isInsideComposite: false)
    }

    // MARK: - Block parsing

    /// Parse a sequence of lines until either EOF or a closing `}` (when
    /// inside a composite). Caller owns the iterator.
    private func parseBlock(
        lines: inout [String],
        index: inout Int,
        isInsideComposite: Bool
    ) -> PlantUMLStateAST {
        var ast = PlantUMLStateAST()
        var lastActivityNode: String? = nil // for chaining `:action;` lines
        var pendingActivityStart = false
        var activityCounter = 0

        while index < lines.count {
            let raw = lines[index]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            index += 1

            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("'") { continue }

            // Composite close
            if isInsideComposite, trimmed == "}" {
                return ast
            }

            // Composite state open: `state Name {`
            if let decl = parseCompositeOpen(trimmed) {
                let children = parseBlock(
                    lines: &lines,
                    index: &index,
                    isInsideComposite: true
                )
                var withChildren = decl
                withChildren.children = children
                ast.states.append(withChildren)
                continue
            }

            // Note
            if let note = parseNote(trimmed) {
                ast.notes.append(note)
                continue
            }

            // Simple state declaration
            if let decl = parseSimpleStateDecl(trimmed) {
                ast.states.append(decl)
                continue
            }

            // Transition
            if let transition = parseTransition(trimmed) {
                ast.transitions.append(transition)
                continue
            }

            // Activity: `start`
            if trimmed.lowercased() == "start" {
                pendingActivityStart = true
                lastActivityNode = "[*]"
                continue
            }

            // Activity: `stop` / `end`
            if trimmed.lowercased() == "stop" || trimmed.lowercased() == "end" {
                if let prev = lastActivityNode, prev != "[*]" {
                    ast.transitions.append(PlantUMLStateTransition(source: prev, target: "[*]"))
                }
                lastActivityNode = nil
                pendingActivityStart = false
                continue
            }

            // Activity: `:action;`
            if trimmed.hasPrefix(":"), trimmed.hasSuffix(";") {
                activityCounter += 1
                let actionId = "activity\(activityCounter)"
                let actionText = String(trimmed.dropFirst().dropLast())
                    .trimmingCharacters(in: .whitespaces)
                ast.states.append(PlantUMLStateDecl(id: actionId, label: actionText))
                if let prev = lastActivityNode {
                    ast.transitions.append(PlantUMLStateTransition(
                        source: prev,
                        target: actionId
                    ))
                } else if pendingActivityStart {
                    ast.transitions.append(PlantUMLStateTransition(
                        source: "[*]",
                        target: actionId
                    ))
                }
                lastActivityNode = actionId
                pendingActivityStart = false
                continue
            }

            ast.unsupportedLines.append(trimmed)
        }

        return ast
    }

    // MARK: - State declarations

    private func parseCompositeOpen(_ line: String) -> PlantUMLStateDecl? {
        guard line.hasSuffix("{") else { return nil }
        let head = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
        guard head.lowercased().hasPrefix("state ") else { return nil }
        let rest = String(head.dropFirst("state ".count)).trimmingCharacters(in: .whitespaces)
        guard let parsed = parseStateHead(rest) else { return nil }
        return PlantUMLStateDecl(id: parsed.id, label: parsed.label)
    }

    private func parseSimpleStateDecl(_ line: String) -> PlantUMLStateDecl? {
        // Avoid swallowing transition lines.
        if line.contains("-->") || line.contains("<--") || line.contains("..>") { return nil }
        guard line.lowercased().hasPrefix("state ") else { return nil }
        let rest = String(line.dropFirst("state ".count)).trimmingCharacters(in: .whitespaces)
        guard let parsed = parseStateHead(rest) else { return nil }
        return PlantUMLStateDecl(id: parsed.id, label: parsed.label)
    }

    /// Parse `Name`, `"Display" as Alias`, `Name as Alias`, `Name : description`.
    private func parseStateHead(_ rest: String) -> (id: String, label: String)? {
        if rest.hasPrefix("\"") {
            if let closing = rest.dropFirst().firstIndex(of: "\"") {
                let display = String(rest[rest.index(after: rest.startIndex)..<closing])
                let after = rest[rest.index(after: closing)...].trimmingCharacters(in: .whitespaces)
                if after.lowercased().hasPrefix("as ") {
                    let alias = after.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    return (String(alias), display)
                }
                return (display, display)
            }
            return nil
        }

        // `Name : description`
        if let colon = rest.firstIndex(of: ":") {
            let id = rest[..<colon].trimmingCharacters(in: .whitespaces)
            let label = rest[rest.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if !id.isEmpty {
                return (id, label)
            }
        }

        // `Name as Alias`
        let parts = rest.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        if parts.count >= 3, parts[1].lowercased() == "as" {
            return (parts[2], parts[0])
        }

        if let first = parts.first { return (first, "") }
        return nil
    }

    // MARK: - Transitions

    private func parseTransition(_ line: String) -> PlantUMLStateTransition? {
        // strip optional `: label`
        var working = line
        var label: String? = nil
        if let labelMarker = line.range(of: " : ") {
            working = String(line[..<labelMarker.lowerBound])
            label = String(line[labelMarker.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        // also support `:label` without surrounding space
        if label == nil, working.contains(": ") {
            let parts = working.components(separatedBy: ": ")
            if parts.count >= 2 {
                working = parts[0]
                label = parts.dropFirst().joined(separator: ": ").trimmingCharacters(in: .whitespaces)
            }
        }

        let arrowPatterns = ["-->", "->", "<--", "..>", "<.."]

        for pattern in arrowPatterns {
            if let range = working.range(of: pattern) {
                let left = working[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                let right = working[range.upperBound...].trimmingCharacters(in: .whitespaces)
                guard !left.isEmpty, !right.isEmpty else { continue }

                let (source, target): (String, String)
                if pattern.first == "<" {
                    source = right
                    target = left
                } else {
                    source = left
                    target = right
                }

                // Sanity: source and target must look like state IDs or `[*]`
                if !isValidStateID(source) || !isValidStateID(target) { continue }

                return PlantUMLStateTransition(source: source, target: target, label: label)
            }
        }
        return nil
    }

    private func isValidStateID(_ s: String) -> Bool {
        if s == "[*]" { return true }
        guard let first = s.first else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_."))
        if !CharacterSet.letters.union(CharacterSet(charactersIn: "_")).contains(first.unicodeScalars.first!) {
            return false
        }
        return s.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    // MARK: - Notes

    private func parseNote(_ line: String) -> PlantUMLStateNote? {
        let lower = line.lowercased()
        guard lower.hasPrefix("note ") else { return nil }
        let rest = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        let positions = ["left of ", "right of ", "top of ", "bottom of ", "over "]
        for pos in positions {
            if rest.lowercased().hasPrefix(pos) {
                let position = String(pos.split(separator: " ").first ?? "")
                let after = rest.dropFirst(pos.count)
                if let colon = after.firstIndex(of: ":") {
                    let target = after[..<colon].trimmingCharacters(in: .whitespaces)
                    let text = after[after.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    return PlantUMLStateNote(attachedTo: target, position: position, text: text)
                }
            }
        }
        return nil
    }
}
