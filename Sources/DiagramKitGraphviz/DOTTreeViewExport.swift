import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits a `TreeViewDiagram` as DOT source. Always emits family +
/// tree-root markers. TreeView has no shape vocabulary so no
/// per-node markers are involved.
enum DOTTreeViewExport {

    static func emit(_ tree: TreeViewDiagram, title: String?) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        lines.append("digraph G {")
        lines.append("  \(DOTRecoveryMarker.emitFamily("treeView"))")
        if let t = title, !t.isEmpty {
            lines.append("  // title: \(singleLine(t))")
        }

        // Convention detection: synthetic `/` at level -1 means "Mermaid
        // multi-root container". Emit each child as a top-level forest
        // declaration; DOT supports multiple zero-in-degree nodes natively.
        // The tree-root marker fires on the FIRST child only (ordering
        // hint for the importer; see DOTTreeViewMapper multi-root path).
        let isSyntheticRoot = (tree.root.name == "/" && tree.root.level == -1)
        let topLevelRoots: [TreeViewNode] = isSyntheticRoot ? tree.root.children : [tree.root]

        if let first = topLevelRoots.first {
            lines.append("  \(DOTRecoveryMarker.emitTreeRoot(first.name))")
        }
        for root in topLevelRoots {
            emitNode(root, indent: "  ", lines: &lines, diagnostics: &diagnostics)
            emitEdges(parent: root, indent: "  ", lines: &lines)
        }

        lines.append("}")
        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    private static func emitNode(
        _ node: TreeViewNode,
        indent: String,
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let id = sanitize(node.name)
        lines.append("\(indent)\(id) [label=\"\(escape(node.name))\"];")
        if id != node.name {
            diagnostics.append(.lossyTransform(
                .idSanitization,
                message: "TreeView node name '\(node.name)' sanitized to DOT id '\(id)'"
            ))
        }
        for child in node.children {
            emitNode(child, indent: indent, lines: &lines, diagnostics: &diagnostics)
        }
    }

    private static func emitEdges(parent: TreeViewNode, indent: String, lines: inout [String]) {
        for child in parent.children {
            lines.append("\(indent)\(sanitize(parent.name)) -> \(sanitize(child.name));")
            emitEdges(parent: child, indent: indent, lines: &lines)
        }
    }

    private static func sanitize(_ raw: String) -> String {
        var out = ""
        for (i, ch) in raw.enumerated() {
            switch ch {
            case "a"..."z", "A"..."Z", "0"..."9", "_":
                if i == 0, ch.isNumber { out.append("_") }
                out.append(ch)
            case " ", "-", ".":
                out.append("_")
            default: break
            }
        }
        // DOT reserves `node`/`edge`/`graph`/`subgraph` as keywords;
        // synthesize `n0` for inputs that sanitize empty (e.g. "/").
        if out.isEmpty { return "n0" }
        switch out {
        case "node", "edge", "graph", "subgraph", "digraph", "strict":
            return "_\(out)"
        default:
            return out
        }
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
         .replacingOccurrences(of: "\r", with: "")
    }

    private static func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
         .replacingOccurrences(of: "\r", with: "\n")
         .split(separator: "\n", omittingEmptySubsequences: false)
         .joined(separator: " ")
    }
}
