import Foundation

/// Returns true when `source` appears to be Structurizr DSL rather than any
/// other known format. This is a narrow probe — it requires `workspace`
/// followed by `{` (with optional name/description strings between).
public func isStructurizrSource(_ source: String) -> Bool {
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    let firstLine = trimmed.split(separator: "\n").first?
        .trimmingCharacters(in: .whitespaces) ?? ""

    // PlantUML guard — @startuml/@startxxx blocks
    if trimmed.contains("@startuml") || trimmed.contains("@start") {
        return false
    }

    // Mermaid guard — first-line diagram headers
    let mermaidHeaders = [
        "graph", "flowchart", "sequenceDiagram", "classDiagram",
        "stateDiagram", "erDiagram", "gantt", "pie", "mindmap",
        "timeline", "gitGraph", "block-beta", "quadrantChart",
        "xychart-beta", "sankey-beta", "journey", "requirementDiagram",
        "C4Context", "C4Container", "C4Component", "C4Dynamic", "C4Deployment",
        "zenuml"
    ]
    let lowerLine = firstLine.lowercased()
    for header in mermaidHeaders.map({ $0.lowercased() }) {
        if lowerLine.hasPrefix(header) { return false }
    }

    // DOT guard — digraph/graph/strict headers
    let dotTokens = lowerLine.split(separator: " ", omittingEmptySubsequences: true)
    if let first = dotTokens.first {
        if first == "digraph" || first == "strict" { return false }
        if first == "graph", dotTokens.count >= 2 {
            let second = dotTokens[1]
            if ["td", "lr", "bt", "rl", "tb"].contains(where: { second.hasPrefix($0) }) {
                return false  // Mermaid graph direction
            }
            return false  // DOT graph header
        }
    }

    // D2 guard — d2 never starts with `workspace`
    // (Structurizr requires workspace keyword)

    let structurizrTokens = StructurizrLexer().tokenize(trimmed)
    guard structurizrTokens.first == .identifier("workspace") else { return false }

    var index = 1
    var stringCount = 0
    while index < structurizrTokens.count {
        if case .string = structurizrTokens[index] {
            stringCount += 1
            guard stringCount <= 2 else { return false }
            index += 1
            continue
        }
        break
    }

    return index < structurizrTokens.count && structurizrTokens[index] == .openBrace
}
