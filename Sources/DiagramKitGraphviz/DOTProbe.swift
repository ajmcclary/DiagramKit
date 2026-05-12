import Foundation

/// Returns true when `source` appears to be Graphviz DOT rather than any
/// other known format. This is a narrow probe — it requires `graph`,
/// `digraph`, or `strict graph` / `strict digraph` structure.
///
/// It must NOT false-match on D2, Mermaid, PlantUML, or Structurizr source.
public func isDOTSource(_ source: String) -> Bool {
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    let firstLine = trimmed.split(separator: "\n").first?
        .trimmingCharacters(in: .whitespaces) ?? ""

    // Bare A -> B without a graph/digraph/strict header is D2-shaped input,
    // to avoid ambiguity. Headers are required for importer routing.

    let lower = firstLine.lowercased()
        .replacingOccurrences(of: "{", with: " { ")

    // PlantUML / Structurizr guards
    if trimmed.contains("@startuml") || trimmed.contains("@start") { return false }
    if trimmed.hasPrefix("workspace {") || trimmed.hasPrefix("workspace{") { return false }

    // Tokenize the first line to avoid prefix-only false matches
    // (e.g. "digraphy" would match hasPrefix("digraph")).
    let tokens = lower.split(separator: " ", omittingEmptySubsequences: true)
    guard let firstToken = tokens.first else { return false }

    // "strict digraph" / "strict graph" — two-token header
    if firstToken == "strict", tokens.count >= 2 {
        let second = tokens[1]
        if second == "digraph" || second == "graph" { return true }
        return false
    }

    // Single-token headers: digraph, graph
    if firstToken == "digraph" { return true }

    if firstToken == "graph" {
        // Reject Mermaid's "graph TD", "graph LR", etc.
        // After "graph", the next token is a direction keyword for Mermaid,
        // or an optional graph name / "{" for DOT.
        if tokens.count >= 2 {
            let second = tokens[1]
            if ["td", "lr", "bt", "rl", "tb"].contains(where: {
                second.hasPrefix($0)
            }) {
                return false
            }
        }
        return true
    }

    return false
}
