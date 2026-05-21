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

/// Returns `true` when body is from an explicit @startmindmap header.
/// `@startwbs` no longer routes here — see `isPlantUMLWBS` below. Mindmap
/// keeps its own dispatch branch in `PlantUMLImporter`.
public func isPlantUMLMindmap(startKind: String, _ body: String) -> Bool {
    startKind == "mindmap"
}

/// Returns `true` when body is from an explicit @startwbs header.
/// Routes to the WBS parser which produces a `TreeViewDiagram` payload
/// (not `MindmapDiagram`).
public func isPlantUMLWBS(startKind: String, _ body: String) -> Bool {
    startKind == "wbs"
}

/// Returns `true` when body is from an explicit @startjson header.
public func isPlantUMLJSON(startKind: String, _ body: String) -> Bool {
    startKind == "json"
}

/// Returns `true` when body is from an explicit @startyaml header.
public func isPlantUMLYAML(startKind: String, _ body: String) -> Bool {
    startKind == "yaml"
}

/// Returns `true` when body contains pure state diagram syntax.
/// Activity markers (start/stop/:text;/partition) are NOT matched here —
/// they belong to `isPlantUMLActivityBody`. Activity must be probed
/// BEFORE state in the cascade.
public func isPlantUMLStateBody(_ body: String) -> Bool {
    let lines = body.split(separator: "\n", omittingEmptySubsequences: true)
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("state ") { return true }
        if trimmed.hasPrefix("[*]") { return true }
    }
    return false
}

/// Returns `true` when body contains activity syntax.
/// Must be probed BEFORE `isPlantUMLStateBody` in the cascade.
public func isPlantUMLActivityBody(_ body: String) -> Bool {
    let lines = body.split(separator: "\n", omittingEmptySubsequences: true)
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // `end` is intentionally excluded — it also closes sequence `alt`/`loop`
        // blocks. Activity uses `stop` to terminate.
        if trimmed == "start" || trimmed == "stop" { return true }
        if trimmed.hasPrefix("partition ") { return true }
        if trimmed.hasPrefix(":") && trimmed.hasSuffix(";") { return true }
        if trimmed.hasPrefix("if ") && trimmed.contains("then") { return true }
    }
    return false
}

/// Returns `true` when body contains PlantUML Information Engineering ER syntax.
public func isPlantUMLERBody(_ body: String) -> Bool {
    let lines = body.split(separator: "\n", omittingEmptySubsequences: true)
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("entity ") { return true }
        if trimmed.range(
            of: #"[|}o]+(--|\.\.)[|{o]+"#,
            options: .regularExpression
        ) != nil {
            return true
        }
    }
    return false
}

/// Returns `true` when body contains PlantUML use-case syntax.
/// Requires use-case-specific markers (`usecase` keyword or `(name)` form).
/// Bare `actor ` alone is ambiguous with sequence diagrams and is intentionally
/// not matched here — the sequence-probe fallback catches that case.
public func isPlantUMLUseCaseBody(_ body: String) -> Bool {
    let lines = body.split(separator: "\n", omittingEmptySubsequences: true)
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("usecase ") {
            return true
        }
        if trimmed.hasPrefix("(") && trimmed.contains(")") { return true }
        if trimmed.hasPrefix(":") && !trimmed.hasSuffix(";") {
            let rest = trimmed.dropFirst()
            if rest.contains(":") { return true }
        }
    }
    return false
}

/// Returns `true` when body contains PlantUML object diagram syntax.
public func isPlantUMLObjectBody(_ body: String) -> Bool {
    let lines = body.split(separator: "\n", omittingEmptySubsequences: true)
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("object ") { return true }
    }
    return false
}

/// Returns `true` when body contains PlantUML component diagram syntax.
/// Requires a component-distinctive token (`[Bracketed]` or `component`
/// keyword); bare `interface` alone routes to class.
public func isPlantUMLComponentBody(_ body: String) -> Bool {
    let lines = body.split(separator: "\n", omittingEmptySubsequences: true)
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("[") && trimmed.contains("]") { return true }
        if trimmed.contains("] --") || trimmed.contains("] ->") { return true }
        if trimmed.hasPrefix("component ") { return true }
    }
    return false
}

/// Returns `true` when body contains PlantUML deployment-diagram syntax.
/// Triggered by deployment-exclusive shape keywords (`node`, `artifact`,
/// `cloud`, `database`, `frame`, `folder`, `package`, `card`, `queue`,
/// `stack`, `storage`, `agent`, `boundary`) declaring a labeled shape
/// or opening a nested block. `actor`/`interface`/`component` are
/// intentionally excluded — they overlap with sequence/use-case/class
/// or are already claimed by the component dialect.
public func isPlantUMLDeploymentBody(_ body: String) -> Bool {
    let deploymentKeywords: Set<String> = [
        "node", "artifact", "database", "cloud", "frame", "folder",
        "package", "card", "queue", "stack", "storage", "agent",
        "boundary"
    ]
    for line in body.split(separator: "\n", omittingEmptySubsequences: true) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let firstToken = trimmed.split(separator: " ", maxSplits: 1).first else { continue }
        if deploymentKeywords.contains(String(firstToken)),
           trimmed.contains("\"") || trimmed.hasSuffix("{") {
            return true
        }
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
