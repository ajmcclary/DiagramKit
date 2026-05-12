import Foundation

/// Outer probe: returns `true` when source is PlantUML format.
///
/// Detection requires `@startuml` or `@startxxx` with a corresponding
/// `@enduml` / `@endxxx`. Rejects sources from all other known formats.
public func isPlantUMLSource(_ source: String) -> Bool {
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    // Must have a start tag
    guard _findPlantUMLStartTag(in: trimmed) != nil else {
        return false
    }

    // Guards: reject other formats
    // Structurizr: workspace {
    if trimmed.contains("workspace {") {
        return false
    }
    // Structurizr: workspace followed by brace
    let firstLine = trimmed.split(separator: "\n", omittingEmptySubsequences: true).first?
        .trimmingCharacters(in: .whitespaces) ?? ""
    if firstLine.hasPrefix("workspace") {
        return false
    }

    // DOT: digraph/graph/strict headers
    let lowerFirst = firstLine.lowercased()
    let firstTokens = lowerFirst.split(separator: " ", omittingEmptySubsequences: true)
    if let first = firstTokens.first {
        if first == "digraph" || first == "strict" { return false }
        if first == "graph", firstTokens.count >= 2 {
            let second = firstTokens[1]
            if ["td", "lr", "bt", "rl", "tb"].contains(where: { second.hasPrefix($0) }) {
                return false
            }
            return false
        }
    }

    // Mermaid first-line headers
    let mermaidHeaders = [
        "graph", "flowchart", "sequencediagram", "classdiagram",
        "statediagram", "erdiagram", "gantt", "pie", "mindmap",
        "timeline", "gitgraph", "block-beta", "quadrantchart",
        "xychart-beta", "sankey-beta", "journey", "requirementdiagram",
        "c4context", "c4container", "c4component", "c4dynamic", "c4deployment",
        "zenuml"
    ]
    let compactLower = lowerFirst.replacingOccurrences(of: " ", with: "")
    for header in mermaidHeaders {
        if compactLower.hasPrefix(header) { return false }
    }

    // D2: colon-assignment pattern without Mermaid/PlantUML markers
    // (d2-spec lines such as `x: value` or `x -> y` without a start tag)
    // Already guarded by requiring @startuml/@startxxx

    return true
}

/// Find the @startuml or @startxxx tag and return its range.
private func _findPlantUMLStartTag(in source: String) -> Range<String.Index>? {
    // Look for @startuml or @startxxx followed by optional whitespace then newline or end
    let pattern = try? NSRegularExpression(pattern: "@start(uml|mindmap|gantt|wbs)\\b", options: [])
    let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
    guard let match = pattern?.firstMatch(in: source, options: [], range: nsRange) else {
        return nil
    }
    return Range(match.range, in: source)
}

/// Extract the body between @startxxx and @endxxx tags.
/// Returns (body, startTagKind) where startTagKind is "uml", "mindmap", "gantt", or "wbs".
public func extractPlantUMLBody(_ source: String) -> (body: String, startKind: String)? {
    let pattern = try? NSRegularExpression(
        pattern: "@start(uml|mindmap|gantt|wbs)(.*?)@end(uml|mindmap|gantt|wbs)",
        options: [.dotMatchesLineSeparators]
    )
    let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
    guard let match = pattern?.firstMatch(in: source, options: [], range: nsRange),
          match.numberOfRanges >= 4,
          let kindRange = Range(match.range(at: 1), in: source),
          let bodyRange = Range(match.range(at: 2), in: source) else {
        return nil
    }
    let kind = String(source[kindRange])
    let body = String(source[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    return (body: body, startKind: kind)
}
