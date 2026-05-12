import Foundation

/// Returns true when `source` appears to be d2 rather than any other known format.
/// This is a narrow probe — it must NOT false-match on Mermaid, DOT, PlantUML,
/// or Structurizr source.
public func isD2Source(_ source: String) -> Bool {
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    let firstLine = trimmed.split(separator: "\n").first?
        .trimmingCharacters(in: .whitespaces) ?? ""

    // Explicit Mermaid headers → not d2
    let mermaidHeaders = [
        "graph", "flowchart", "sequenceDiagram", "classDiagram", "erDiagram",
        "stateDiagram", "gantt", "pie", "mindmap", "timeline", "requirementDiagram",
        "gitGraph", "sankey-beta", "block-beta", "packet-beta", "kanban",
        "architecture-beta", "radar-beta", "treemap-beta", "venn-beta",
        "ishikawa-beta", "treeView-beta", "eventModeling-beta", "wardley-beta",
        "c4Context", "zenuml"
    ]
    for header in mermaidHeaders {
        if firstLine.hasPrefix(header) { return false }
    }

    // DOT headers → not d2
    if firstLine.hasPrefix("digraph") || firstLine.hasPrefix("graph ") || firstLine.hasPrefix("strict ") {
        return false
    }

    // PlantUML headers → not d2
    if trimmed.contains("@startuml") || trimmed.contains("@start") {
        return false
    }

    // Structurizr headers → not d2
    if trimmed.hasPrefix("workspace {") || trimmed.hasPrefix("workspace{") {
        return false
    }

    // d2 probe signatures (any one is sufficient):

    // 1. Edge arrow syntax (most distinctive — now safe after excluding
    //    Mermaid with `->>`, DOT with `->` in `digraph`, and PlantUML with `->`)
    if trimmed.contains("->") || trimmed.contains("<->") { return true }

    // 2. Dot-chained keys with colon assignment (distinctive d2 pattern:
    //    e.g. `a.b.c: value` — common in d2, rare in other formats)
    for line in trimmed.split(separator: "\n") {
        let stripped = line.trimmingCharacters(in: .whitespaces)
        if stripped.hasPrefix("#") || stripped.hasPrefix("//") { continue }
        if stripped.contains(":") && stripped.contains(".") {
            let parts = stripped.split(separator: ":")
            if let key = parts.first, key.contains(".") {
                return true
            }
        }
    }

    // 3. Block syntax with colon assignment
    let hasColonAssign = trimmed.contains(": ")
    let hasBlockSyntax: Bool = {
        for line in trimmed.split(separator: "\n") {
            let stripped = line.trimmingCharacters(in: .whitespaces)
            if stripped == "{" || stripped.hasSuffix(" {") { return true }
        }
        return false
    }()

    if hasBlockSyntax && hasColonAssign { return true }

    return false
}
