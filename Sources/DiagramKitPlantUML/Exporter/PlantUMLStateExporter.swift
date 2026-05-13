import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits PlantUML state diagram source from a `ParsedGraphModel`
/// (the `DiagramPayload.stateDiagram` payload).
///
/// Pseudostates encoded as `<parent>_start` / `<parent>_end` are
/// rewritten back into `[*]`. Composite subgraphs become
/// `state Name { … }` blocks. Notes are not currently round-tripped
/// because the payload doesn't carry them.
enum PlantUMLStateExport {

    static func emit(_ graph: ParsedGraphModel) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        lines.append("@startuml")

        // Track which node IDs are owned by which subgraph so we don't
        // emit them at top-level.
        var ownedBy: [String: String] = [:]
        for subgraph in graph.subgraphs {
            collectOwnership(subgraph, ownerID: subgraph.id, into: &ownedBy)
        }

        // Top-level simple states first
        for entry in graph.nodesInOrder where ownedBy[entry.id] == nil {
            if shouldSkipNode(entry.node) { continue }
            lines.append(stateDecl(for: entry.id, node: entry.node))
        }

        // Subgraph blocks
        for subgraph in graph.subgraphs {
            emitSubgraph(subgraph, graph: graph, ownedBy: ownedBy, into: &lines)
        }

        // Edges — rewrite pseudostate IDs back to [*].
        for edge in graph.edges {
            let source = restorePseudostate(edge.source)
            let target = restorePseudostate(edge.target)
            if let label = edge.label, !label.isEmpty {
                lines.append("\(source) --> \(target) : \(escape(label))")
            } else {
                lines.append("\(source) --> \(target)")
            }
        }

        lines.append("@enduml")

        return DiagramExportResult(
            source: lines.joined(separator: "\n"),
            diagnostics: diagnostics
        )
    }

    private static func collectOwnership(
        _ subgraph: original_src_types.MermaidSubgraph,
        ownerID: String,
        into map: inout [String: String]
    ) {
        for nodeId in subgraph.nodeIds {
            map[nodeId] = ownerID
        }
        for child in subgraph.children {
            collectOwnership(child, ownerID: child.id, into: &map)
        }
    }

    private static func emitSubgraph(
        _ subgraph: original_src_types.MermaidSubgraph,
        graph: ParsedGraphModel,
        ownedBy: [String: String],
        into lines: inout [String]
    ) {
        lines.append("state \(subgraph.id) {")
        for childId in subgraph.nodeIds {
            if let entry = graph.nodesInOrder.first(where: { $0.id == childId }) {
                if shouldSkipNode(entry.node) { continue }
                lines.append("  \(stateDecl(for: entry.id, node: entry.node))")
            }
        }
        for child in subgraph.children {
            emitSubgraph(child, graph: graph, ownedBy: ownedBy, into: &lines)
        }
        lines.append("}")
    }

    /// Skip nodes that exist only as pseudostate placeholders — they
    /// are inlined into transitions as `[*]`.
    private static func shouldSkipNode(_ node: original_src_types.MermaidNode) -> Bool {
        switch node.shape {
        case .stateStart, .stateEnd: return true
        default: return false
        }
    }

    private static func stateDecl(for id: String, node: original_src_types.MermaidNode) -> String {
        if !node.label.isEmpty, node.label != id {
            return "state \(id) : \(escape(node.label))"
        }
        return "state \(id)"
    }

    private static func restorePseudostate(_ id: String) -> String {
        if id.hasSuffix("_start") || id.hasSuffix("_end") {
            return "[*]"
        }
        return id
    }

    private static func escape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
