import Foundation
import DiagramKitImport

/// Parses PlantUML C4 macro invocations.
///
/// Each declaration is `Macro(alias, "Label", "Technology"?, "Description"?)`.
/// Relationships are `Rel(from, to, "Label", "Technology"?)` (and the
/// `Rel_Back` variant). Lines that don't match a recognized macro are
/// collected as unsupported.
public struct PlantUMLC4Parser {

    public init() {}

    private static let declarationMacros: Set<String> = [
        "Person", "Person_Ext",
        "System", "SystemDb", "SystemQueue",
        "System_Ext", "SystemDb_Ext", "SystemQueue_Ext",
        "Container", "ContainerDb", "ContainerQueue",
        "Container_Ext", "ContainerDb_Ext", "ContainerQueue_Ext",
        "Component", "ComponentDb", "ComponentQueue",
        "Component_Ext", "ComponentDb_Ext", "ComponentQueue_Ext"
    ]

    /// Mirror of C4ShapeType.hasTechnologySlot, keyed by macro name.
    /// Container/Component family macros take (alias, label, techn?, descr?);
    /// Person/System family macros take (alias, label, descr?). Parsing has
    /// to dispatch on this distinction or technology↔description silently
    /// swap on import.
    private static let macroHasTechnologySlot: [String: Bool] = [
        "Person": false, "Person_Ext": false,
        "System": false, "SystemDb": false, "SystemQueue": false,
        "System_Ext": false, "SystemDb_Ext": false, "SystemQueue_Ext": false,
        "Container": true, "ContainerDb": true, "ContainerQueue": true,
        "Container_Ext": true, "ContainerDb_Ext": true, "ContainerQueue_Ext": true,
        "Component": true, "ComponentDb": true, "ComponentQueue": true,
        "Component_Ext": true, "ComponentDb_Ext": true, "ComponentQueue_Ext": true
    ]

    private static let relationshipMacros: Set<String> = [
        "Rel", "BiRel", "Rel_Back",
        "Rel_U", "Rel_D", "Rel_L", "Rel_R",
        "Rel_Up", "Rel_Down", "Rel_Left", "Rel_Right"
    ]

    public func parse(_ body: String) -> PlantUMLC4AST {
        var ast = PlantUMLC4AST()
        for raw in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("'") { continue }
            if trimmed.hasPrefix("!include") { continue }

            guard let (macro, body) = splitMacroInvocation(trimmed) else {
                ast.unsupportedLines.append(trimmed)
                continue
            }

            let args = splitArguments(body)
            if Self.declarationMacros.contains(macro), args.count >= 2 {
                let technology: String?
                let description: String?
                if Self.macroHasTechnologySlot[macro] == true {
                    technology = args.count >= 3 ? stripQuotes(args[2]) : nil
                    description = args.count >= 4 ? stripQuotes(args[3]) : nil
                } else {
                    technology = nil
                    description = args.count >= 3 ? stripQuotes(args[2]) : nil
                }
                ast.declarations.append(PlantUMLC4Declaration(
                    macro: macro,
                    alias: args[0],
                    label: stripQuotes(args[1]),
                    technology: technology,
                    description: description
                ))
                continue
            }
            if Self.relationshipMacros.contains(macro), args.count >= 3 {
                ast.relationships.append(PlantUMLC4Relationship(
                    macro: macro,
                    from: args[0],
                    to: args[1],
                    label: stripQuotes(args[2]),
                    technology: args.count >= 4 ? stripQuotes(args[3]) : nil
                ))
                continue
            }
            ast.unsupportedLines.append(trimmed)
        }
        return ast
    }

    /// Match `Macro(...)` and split into (`Macro`, `...`).
    private func splitMacroInvocation(_ line: String) -> (macro: String, body: String)? {
        guard let openParen = line.firstIndex(of: "(") else { return nil }
        guard let closeParen = line.lastIndex(of: ")"), closeParen > openParen else { return nil }
        let macro = String(line[..<openParen]).trimmingCharacters(in: .whitespaces)
        let body = String(line[line.index(after: openParen)..<closeParen])
        return (macro, body)
    }

    /// Split a macro argument list on top-level commas (quoted strings
    /// are protected). Trims surrounding whitespace from each argument.
    private func splitArguments(_ raw: String) -> [String] {
        var args: [String] = []
        var current = ""
        var depth = 0
        var insideQuote = false
        for char in raw {
            if char == "\"" {
                insideQuote.toggle()
                current.append(char)
                continue
            }
            if !insideQuote {
                if char == "(" { depth += 1 }
                else if char == ")" { depth -= 1 }
                if char == ",", depth == 0 {
                    args.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                    continue
                }
            }
            current.append(char)
        }
        let final = current.trimmingCharacters(in: .whitespaces)
        if !final.isEmpty || !args.isEmpty { args.append(final) }
        return args
    }

    private func stripQuotes(_ raw: String) -> String {
        guard raw.hasPrefix("\""), raw.hasSuffix("\""), raw.count >= 2 else { return raw }
        return String(raw.dropFirst().dropLast())
    }
}
