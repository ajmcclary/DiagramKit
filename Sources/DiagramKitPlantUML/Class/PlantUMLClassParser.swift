import Foundation
import DiagramKitImport

/// Line-based parser for PlantUML class diagram bodies.
///
/// Operates on the body text between `@startuml` and `@enduml`.
/// Handles class/interface/abstract/enum/annotation declarations,
/// member blocks, the common relationship arrows, and notes.
///
/// Unsupported lines (stereotypes, packages, generics, hidden) are
/// collected in `PlantUMLClassAST.unsupportedLines` so the importer
/// can surface them as diagnostics.
public struct PlantUMLClassParser {

    public init() {}

    public func parse(_ body: String) -> PlantUMLClassAST {
        var ast = PlantUMLClassAST()
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)

        var iterator = lines.makeIterator()
        while let raw = iterator.next() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("'") { continue } // PlantUML single-line comment
            if trimmed.hasPrefix("/'") { continue } // multi-line comment opener; skipped naively

            if let note = parseNote(trimmed) {
                ast.notes.append(note)
                continue
            }

            if let decl = parseClassDeclarationOpen(trimmed) {
                let (members, _) = consumeMemberBlock(iterator: &iterator)
                var withMembers = decl
                withMembers.members = members
                ast.classes.append(withMembers)
                continue
            }

            if let decl = parseClassDeclarationSimple(trimmed) {
                ast.classes.append(decl)
                continue
            }

            if let rel = parseRelationship(trimmed) {
                ast.relationships.append(rel)
                continue
            }

            // Inline member declarations like `Foo : +bar() : Int`
            if let (className, member) = parseInlineMember(trimmed) {
                if let idx = ast.classes.firstIndex(where: { $0.name == className }) {
                    ast.classes[idx].members.append(member)
                } else {
                    // Auto-create the class if unknown so the member isn't lost.
                    var decl = PlantUMLClassDecl(kind: .classDecl, name: className)
                    decl.members = [member]
                    ast.classes.append(decl)
                }
                continue
            }

            ast.unsupportedLines.append(trimmed)
        }
        return ast
    }

    // MARK: - Declarations

    /// `class Name {` (open brace at end of line) → returns the decl
    /// without members; caller consumes the block.
    private func parseClassDeclarationOpen(_ line: String) -> PlantUMLClassDecl? {
        guard line.hasSuffix("{") else { return nil }
        let head = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
        return parseDeclarationHead(head)
    }

    /// `class Name` (no body).
    private func parseClassDeclarationSimple(_ line: String) -> PlantUMLClassDecl? {
        if line.hasSuffix("{") { return nil }
        return parseDeclarationHead(line)
    }

    private func parseDeclarationHead(_ head: String) -> PlantUMLClassDecl? {
        let lower = head.lowercased()
        let kind: PlantUMLClassDecl.Kind
        let rest: String

        if lower.hasPrefix("abstract class ") {
            kind = .abstractDecl
            rest = String(head.dropFirst("abstract class ".count)).trimmingCharacters(in: .whitespaces)
        } else if lower.hasPrefix("abstract ") {
            kind = .abstractDecl
            rest = String(head.dropFirst("abstract ".count)).trimmingCharacters(in: .whitespaces)
        } else if lower.hasPrefix("class ") {
            kind = .classDecl
            rest = String(head.dropFirst("class ".count)).trimmingCharacters(in: .whitespaces)
        } else if lower.hasPrefix("interface ") {
            kind = .interfaceDecl
            rest = String(head.dropFirst("interface ".count)).trimmingCharacters(in: .whitespaces)
        } else if lower.hasPrefix("enum ") {
            kind = .enumDecl
            rest = String(head.dropFirst("enum ".count)).trimmingCharacters(in: .whitespaces)
        } else if lower.hasPrefix("annotation ") {
            kind = .annotationDecl
            rest = String(head.dropFirst("annotation ".count)).trimmingCharacters(in: .whitespaces)
        } else {
            return nil
        }

        // Forms:
        //   Name
        //   "Display Name" as Alias
        //   Name as Alias
        //   Name<T>      (generic; treated as name for now)
        if rest.hasPrefix("\"") {
            // `"Display" as Alias`
            if let closingQuote = rest.dropFirst().firstIndex(of: "\"") {
                let display = String(rest[rest.index(after: rest.startIndex)..<closingQuote])
                let after = rest[rest.index(after: closingQuote)...].trimmingCharacters(in: .whitespaces)
                if after.lowercased().hasPrefix("as ") {
                    let alias = after.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    return PlantUMLClassDecl(kind: kind, name: alias, label: display)
                }
                return PlantUMLClassDecl(kind: kind, name: display, label: display)
            }
        }

        let parts = rest.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        if parts.count >= 3, parts[1].lowercased() == "as" {
            return PlantUMLClassDecl(kind: kind, name: parts[2], label: parts[0])
        }
        if let first = parts.first {
            return PlantUMLClassDecl(kind: kind, name: first)
        }
        return nil
    }

    /// Consume lines until a `}` terminator. Each non-empty interior
    /// line is parsed as a member declaration.
    private func consumeMemberBlock(
        iterator: inout IndexingIterator<[Substring]>
    ) -> (members: [PlantUMLClassMember], unsupported: [String]) {
        var members: [PlantUMLClassMember] = []
        var unsupported: [String] = []
        while let raw = iterator.next() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed == "}" { return (members, unsupported) }
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("'") { continue }
            if let member = parseMember(trimmed) {
                members.append(member)
            } else {
                unsupported.append(trimmed)
            }
        }
        return (members, unsupported)
    }

    private func parseMember(_ raw: String) -> PlantUMLClassMember? {
        var s = raw
        let visibility: PlantUMLClassMember.Visibility
        if let first = s.first, let vis = visibilityFromMarker(first) {
            visibility = vis
            s = String(s.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else {
            visibility = .none
        }

        // Method: contains `(...)`
        if let openParen = s.firstIndex(of: "("),
           let closeParen = s.lastIndex(of: ")"),
           openParen < closeParen {
            let identifier = s[..<openParen].trimmingCharacters(in: .whitespaces)
            let parameters = s[s.index(after: openParen)..<closeParen].trimmingCharacters(in: .whitespaces)
            let afterParen = s[s.index(after: closeParen)...].trimmingCharacters(in: .whitespaces)
            let returnType = parseTypeAnnotation(afterParen)
            return PlantUMLClassMember(
                visibility: visibility,
                kind: .method,
                identifier: identifier,
                parameters: parameters,
                typeAnnotation: returnType
            )
        }

        // Field: `name : Type` or `name`
        if let colon = s.firstIndex(of: ":") {
            let name = s[..<colon].trimmingCharacters(in: .whitespaces)
            let type = s[s.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return PlantUMLClassMember(visibility: visibility, kind: .field, identifier: name, typeAnnotation: type)
        }
        if !s.isEmpty {
            return PlantUMLClassMember(visibility: visibility, kind: .field, identifier: s)
        }
        return nil
    }

    private func parseTypeAnnotation(_ raw: String) -> String {
        // After a `)` we expect either nothing or `: Type` / `Type`.
        var s = raw
        if s.hasPrefix(":") {
            s = String(s.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        return s
    }

    private func visibilityFromMarker(_ c: Character) -> PlantUMLClassMember.Visibility? {
        switch c {
        case "+": return .publicVis
        case "-": return .privateVis
        case "#": return .protectedVis
        case "~": return .packageVis
        default: return nil
        }
    }

    // MARK: - Inline member `Foo : +bar() : Int`

    private func parseInlineMember(_ line: String) -> (className: String, member: PlantUMLClassMember)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let className = line[..<colon].trimmingCharacters(in: .whitespaces)
        // className must be a single identifier (no spaces, no operators)
        if className.contains(" ") || className.isEmpty { return nil }
        let memberText = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard let member = parseMember(memberText) else { return nil }
        return (className, member)
    }

    // MARK: - Relationships

    /// Detect the four-segment arrow grammar
    /// `[card?] LHS [LCAP] (line) [RCAP] [card?] RHS [: label]`.
    private func parseRelationship(_ line: String) -> PlantUMLClassRelationship? {
        // Strip optional `: label`
        var working = line
        var label: String? = nil
        if let labelMarker = line.range(of: " : ") {
            working = String(line[..<labelMarker.lowerBound])
            label = String(line[labelMarker.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        // Find the line segment (one of `--`, `..`, `<--`, `-->`, `<..`, `..>`, etc.)
        let arrowPatterns = [
            "<|--", "--|>", "<|..", "..|>",
            "*--", "--*", "o--", "--o",
            "<--", "-->", "<..", "..>",
            "..", "--"
        ]

        for pattern in arrowPatterns {
            if let r = working.range(of: pattern) {
                let leftPart = String(working[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                let rightPart = String(working[r.upperBound...]).trimmingCharacters(in: .whitespaces)

                guard !leftPart.isEmpty, !rightPart.isEmpty else { continue }

                let (leftId, leftCard) = splitCardinality(leftPart, fromRight: true)
                let (rightId, rightCard) = splitCardinality(rightPart, fromRight: false)

                // Quick sanity: IDs must look like identifiers (allow letters/digits/_)
                if !looksLikeID(leftId) || !looksLikeID(rightId) { continue }

                let (leftShape, rightShape, lineStyle) = decodeArrow(pattern: pattern)

                return PlantUMLClassRelationship(
                    leftId: leftId,
                    rightId: rightId,
                    leftEndpoint: leftShape,
                    rightEndpoint: rightShape,
                    lineStyle: lineStyle,
                    label: label,
                    leftCardinality: leftCard,
                    rightCardinality: rightCard
                )
            }
        }
        return nil
    }

    private func looksLikeID(_ s: String) -> Bool {
        guard let first = s.first else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_."))
        if !CharacterSet.letters.union(CharacterSet(charactersIn: "_")).contains(first.unicodeScalars.first!) {
            return false
        }
        return s.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func splitCardinality(_ raw: String, fromRight: Bool) -> (id: String, cardinality: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("\"") else { return (trimmed, nil) }
        // Cardinality is a quoted string adjacent to the line. From the
        // right side we strip from the start; from the left, from the end.
        if fromRight {
            // `LHS "card"` → id is the part before the quote
            if let firstQuote = trimmed.lastIndex(of: "\"") {
                let beforeQuote = trimmed[..<firstQuote]
                if let openQuote = beforeQuote.lastIndex(of: "\"") {
                    let card = trimmed[beforeQuote.index(after: openQuote)..<firstQuote]
                    let idPart = trimmed[..<openQuote].trimmingCharacters(in: .whitespaces)
                    return (idPart, String(card))
                }
            }
        } else {
            // `"card" RHS`
            if let firstQuote = trimmed.firstIndex(of: "\"") {
                let afterQuote = trimmed[trimmed.index(after: firstQuote)...]
                if let closeQuote = afterQuote.firstIndex(of: "\"") {
                    let card = afterQuote[..<closeQuote]
                    let idPart = trimmed[trimmed.index(after: closeQuote)...].trimmingCharacters(in: .whitespaces)
                    return (idPart, String(card))
                }
            }
        }
        return (trimmed, nil)
    }

    /// Decode an arrow pattern into (left endpoint shape, right endpoint shape, line style).
    private func decodeArrow(pattern: String) -> (PlantUMLEndpointShape, PlantUMLEndpointShape, PlantUMLLineStyle) {
        let isDotted = pattern.contains("..")

        var left: PlantUMLEndpointShape = .none
        var right: PlantUMLEndpointShape = .none

        // Identify leading/trailing markers.
        if pattern.hasPrefix("<|") {
            left = .inheritance
        } else if pattern.hasPrefix("*") {
            left = .composition
        } else if pattern.hasPrefix("o") {
            left = .aggregation
        } else if pattern.hasPrefix("<") {
            left = .dependency
        }

        if pattern.hasSuffix("|>") {
            right = .inheritance
        } else if pattern.hasSuffix("*") {
            right = .composition
        } else if pattern.hasSuffix("o") {
            right = .aggregation
        } else if pattern.hasSuffix(">") {
            right = .dependency
        }

        return (left, right, isDotted ? .dotted : .solid)
    }

    // MARK: - Notes

    /// Parses `note <position> of <Target> : <text>` and the alias
    /// form `note "text" as N1` (kept as unattached for now).
    private func parseNote(_ line: String) -> PlantUMLClassNote? {
        let lower = line.lowercased()
        guard lower.hasPrefix("note ") else { return nil }
        // Forms:
        //   note left of A : text
        //   note right of A : text
        //   note top of A : text
        //   note bottom of A : text
        //   note over A : text
        //   note "text" as N1
        let rest = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        if rest.lowercased().hasPrefix("\"") {
            // alias form — store with no attachment
            if let firstQuote = rest.firstIndex(of: "\"") {
                let afterFirst = rest[rest.index(after: firstQuote)...]
                if let closeQuote = afterFirst.firstIndex(of: "\"") {
                    return PlantUMLClassNote(text: String(afterFirst[..<closeQuote]))
                }
            }
            return nil
        }

        let positions = ["left of ", "right of ", "top of ", "bottom of ", "over "]
        for pos in positions {
            if rest.lowercased().hasPrefix(pos) {
                let position = String(pos.split(separator: " ").first ?? "")
                let after = rest.dropFirst(pos.count)
                if let colon = after.firstIndex(of: ":") {
                    let target = after[..<colon].trimmingCharacters(in: .whitespaces)
                    let text = after[after.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    return PlantUMLClassNote(
                        attachedTo: target,
                        position: position,
                        text: text
                    )
                }
            }
        }
        return nil
    }
}
