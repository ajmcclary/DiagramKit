import Foundation

/// Returns true when `source` appears to be d2 rather than any other known format.
/// This is a narrow probe — it must NOT false-match on Mermaid, DOT, PlantUML,
/// or Structurizr source.
public func isD2Source(_ source: String) -> Bool {
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    // Strip leading frontmatter (`---\n…\n---\n…`) so that Mermaid sources
    // wrapped in YAML frontmatter still expose their family header for the
    // dispatch check below. Mirrors `_parseFrontMatterAndStripped` in
    // DiagramKitModel but kept local to avoid a heavyweight dependency for
    // a probe call.
    let dispatchSource = _stripLeadingFrontmatter(trimmed)
    let firstLine = dispatchSource.split(separator: "\n").first?
        .trimmingCharacters(in: .whitespaces) ?? ""

    // Explicit Mermaid headers → not d2. Each header is matched as a token
    // (followed by end-of-line, whitespace, or a non-identifier character)
    // so probing a real diagram body like `block\n  columns 3\n  A --> B`
    // is correctly rejected. Without the token check, `block\n  ... -->`
    // would be claimed by D2 (because of the `->`) and fail downstream.
    //
    // Token matching with hyphen-as-boundary means the bare header also
    // catches its `-beta` / `-v2` / `-elk` variants (e.g. `block` matches
    // `block-beta`, `flowchart` matches `flowchart-elk`, `classDiagram`
    // matches `classDiagram-v2`). Headers are compared case-insensitively
    // so Mermaid's permissive header casing (e.g. `eventmodeling` vs
    // `eventModeling-beta`) does not slip through.
    let mermaidHeaders = [
        "graph", "flowchart", "sequenceDiagram", "classDiagram", "erDiagram",
        "stateDiagram", "state", "gantt", "pie", "mindmap", "timeline",
        "requirementDiagram", "requirement", "gitGraph", "sankey", "block",
        "packet", "kanban", "architecture", "radar", "treemap", "venn",
        "ishikawa", "treeView", "eventModeling", "eventmodeling", "wardley",
        "xychart", "quadrantChart", "journey", "zenuml",
        "c4Context", "C4Context", "C4Container", "C4Component",
        "C4Deployment", "C4Dynamic"
    ]
    for header in mermaidHeaders {
        if _firstLineStartsWithToken(firstLine, prefix: header) { return false }
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

/// True iff `line` begins with `prefix` followed by a token boundary
/// (end of string or any non-letter/digit/underscore). Hyphens count as a
/// boundary so `block` still matches `block-beta`. Matching is
/// case-insensitive because Mermaid is permissive about header casing.
private func _firstLineStartsWithToken(_ line: String, prefix: String) -> Bool {
    let lowerLine = line.lowercased()
    let lowerPrefix = prefix.lowercased()
    guard lowerLine.hasPrefix(lowerPrefix) else { return false }
    let after = lowerLine.index(lowerLine.startIndex, offsetBy: lowerPrefix.count)
    if after == lowerLine.endIndex { return true }
    let next = lowerLine[after]
    return !next.isLetter && !next.isNumber && next != "_"
}

/// Drop a leading YAML-frontmatter block delimited by `---` so the next
/// header dispatch sees the actual diagram body. Mirrors the canonical
/// behaviour in `DiagramKitModel._parseFrontMatterAndStripped` but does not
/// pull in that module just for a probe.
private func _stripLeadingFrontmatter(_ source: String) -> String {
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard let firstNonBlank = lines.firstIndex(where: {
        !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }) else {
        return source
    }
    guard lines[firstNonBlank].trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
        return source
    }
    var lastMarker: Int?
    var cursor = firstNonBlank + 1
    while cursor < lines.endIndex {
        if lines[cursor].trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
            lastMarker = cursor
        }
        cursor += 1
    }
    guard let marker = lastMarker else { return source }
    let body = lines[(marker + 1)...].joined(separator: "\n")
    return body.trimmingCharacters(in: .whitespacesAndNewlines)
}
