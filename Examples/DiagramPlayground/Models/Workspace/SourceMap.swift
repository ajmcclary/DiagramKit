//
//  SourceMap.swift
//  DiagramPlayground
//
//  Heuristic line → node id mapping used by bidirectional selection.
//
//  Phase 2 cannot lean on importer-provided source ranges (the
//  DiagramImportResult doesn't carry per-node spans today). Instead
//  we scan each source line for the first identifier-shape token and
//  treat that as the node id. Good enough for the design's hover
//  preview; the importer-range refit lands when the library exposes
//  ranges as a first-class API.
//

import Foundation

public struct SourceMap: Sendable, Equatable {

    public let lineToNode: [Int: String]
    public let nodeToLine: [String: Int]

    public init(source: String, format: SourceFormat) {
        var lineToNode: [Int: String] = [:]
        var nodeToLine: [String: Int] = [:]
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, raw) in lines.enumerated() {
            let line = String(raw)
            guard let identifier = Self.firstIdentifier(in: line, format: format) else {
                continue
            }
            lineToNode[index] = identifier
            // First mention wins so node→line jumps to the declaration,
            // not a later usage.
            if nodeToLine[identifier] == nil {
                nodeToLine[identifier] = index
            }
        }
        self.lineToNode = lineToNode
        self.nodeToLine = nodeToLine
    }

    public static let empty = SourceMap(source: "", format: .mermaid)

    // MARK: - Identifier extraction

    /// Returns the first identifier-shape token on `line`, ignoring
    /// keywords that match a diagram-type declaration.
    private static func firstIdentifier(in line: String, format: SourceFormat) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Skip pure-comment lines.
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("%%") || trimmed.hasPrefix("#") {
            return nil
        }

        // Skip diagram-type declarations.
        for keyword in Self.skippedKeywords[format] ?? [] {
            if trimmed.hasPrefix(keyword) {
                return nil
            }
        }

        var current = ""
        for ch in trimmed {
            if ch.isLetter || ch.isNumber || ch == "_" {
                current.append(ch)
                continue
            }
            break
        }
        return current.isEmpty ? nil : current
    }

    private static let skippedKeywords: [SourceFormat: [String]] = [
        .mermaid:    ["graph", "flowchart", "sequenceDiagram", "classDiagram",
                      "stateDiagram", "stateDiagram-v2", "erDiagram", "gantt",
                      "timeline", "mindmap", "journey", "gitGraph", "pie",
                      "quadrantChart", "requirementDiagram", "C4Context",
                      "C4Container", "C4Component", "C4Dynamic", "C4Deployment",
                      "block", "block-beta", "architecture-beta",
                      "sankey-beta", "xychart-beta", "info", "kanban"],
        .d2:         [],
        .graphviz:   ["digraph", "graph", "strict"],
        .structurizr: ["workspace"],
        .plantuml:   ["@startuml", "@enduml"]
    ]
}
