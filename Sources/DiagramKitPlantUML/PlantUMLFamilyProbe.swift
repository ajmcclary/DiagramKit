import Foundation

/// Family-specific probe functions. Each operates on the PlantUML body
/// (text between @startuml and @enduml), not the full source.

/// Returns `true` when body contains C4-specific syntax.
public func isPlantUMLC4Body(_ body: String) -> Bool {
    body.contains("!include <C4/")
        || body.contains("Person(")
        || body.contains("System(")
        || body.contains("Container(")
        || body.contains("System_Ext(")
}

/// Returns `true` when body is from an explicit @startgantt header.
/// The startKind is passed in from the outer probe.
public func isPlantUMLGantt(startKind: String, _ body: String) -> Bool {
    startKind == "gantt"
}

/// Returns `true` when body is from an explicit @startmindmap or @startwbs header.
public func isPlantUMLMindmap(startKind: String, _ body: String) -> Bool {
    startKind == "mindmap" || startKind == "wbs"
}

/// Returns `true` when body contains state/activity syntax.
public func isPlantUMLStateBody(_ body: String) -> Bool {
    let lines = body.split(separator: "\n", omittingEmptySubsequences: true)
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("state ") || trimmed.hasPrefix("[*]") { return true }
        if trimmed.hasPrefix("partition") { return true }
        // Activity syntax: start/stop keywords (but not bare "end",
        // which is also a block closer in sequence/class diagrams)
        if trimmed == "start" || trimmed == "stop" { return true }
        // Activity action syntax: `:text;`
        if trimmed.hasPrefix(":") && trimmed.hasSuffix(";") { return true }
    }
    return false
}

/// Returns `true` when body contains class diagram syntax.
public func isPlantUMLClassBody(_ body: String) -> Bool {
    let lines = body.split(separator: "\n", omittingEmptySubsequences: true)
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        if lower.hasPrefix("class ") || lower.hasPrefix("interface ") { return true }
        if lower.hasPrefix("abstract class") || lower.hasPrefix("abstract ") { return true }
        if lower.hasPrefix("enum ") || lower.hasPrefix("annotation ") { return true }
        // Relationship arrows (excluding sequence arrows like ->, -->, ->>
        // which use single/double/triple hyphens without the | or * or o markers)
        if trimmed.contains("--|>") || trimmed.contains("..|>") { return true }
        if trimmed.contains("*--") || trimmed.contains("--*") { return true }
        if trimmed.contains("o--") || trimmed.contains("--o") { return true }
        if trimmed.contains("<|--") || trimmed.contains("<|..") { return true }
        // Plain association: `Word -- Word` (allowing optional surrounding
        // whitespace and dotted qualifiers). Bare `--` inside text (e.g.
        // `note: --some-flag`) no longer false-matches.
        if !trimmed.contains("-->") && !trimmed.contains("->"),
           trimmed.range(
               of: #"[A-Za-z_][A-Za-z0-9_.]*\s*--\s*[A-Za-z_][A-Za-z0-9_.]*"#,
               options: .regularExpression
           ) != nil {
            return true
        }
        // Dependency: ..> (but needs to be a word relationship, not just any ..>)
        if trimmed.contains("..>") && !trimmed.contains("->") { return true }
        // Visibility markers for class members
        if trimmed.hasPrefix("+") || trimmed.hasPrefix("-")
            || trimmed.hasPrefix("#") || trimmed.hasPrefix("~") { return true }
    }
    return false
}
