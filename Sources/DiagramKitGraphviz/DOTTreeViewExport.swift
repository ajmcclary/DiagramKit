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

        // Names repeat in ordinary trees (two `index.ts`, a directory
        // holding a same-named entry); ids must not.
        let ids = _uniqueTreeIDs(roots: topLevelRoots, children: { $0.children }, base: { sanitize($0.name) })
        if let first = topLevelRoots.first {
            // The first root always keeps its own id (ids are assigned in
            // pre-order), so the marker names it as before.
            lines.append("  \(DOTRecoveryMarker.emitTreeRoot(first.name))")
        }
        for (i, root) in topLevelRoots.enumerated() {
            emitNode(root, path: [i], ids: ids, indent: "  ", lines: &lines, diagnostics: &diagnostics)
            emitEdges(parent: root, path: [i], ids: ids, indent: "  ", lines: &lines)
        }

        lines.append("}")
        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    private static func emitNode(
        _ node: TreeViewNode,
        path: [Int],
        ids: [[Int]: String],
        indent: String,
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let id = ids[path] ?? sanitize(node.name)
        lines.append("\(indent)\(id) [label=\"\(escape(node.name))\"];")
        if sanitize(node.name) != node.name {
            diagnostics.append(.lossyTransform(
                .idSanitization,
                message: "TreeView node name '\(node.name)' sanitized to DOT id '\(id)'"
            ))
        }
        for (i, child) in node.children.enumerated() {
            emitNode(child, path: path + [i], ids: ids, indent: indent, lines: &lines, diagnostics: &diagnostics)
        }
    }

    private static func emitEdges(
        parent: TreeViewNode, path: [Int], ids: [[Int]: String], indent: String, lines: inout [String]
    ) {
        for (i, child) in parent.children.enumerated() {
            let childPath = path + [i]
            lines.append("\(indent)\(ids[path] ?? sanitize(parent.name)) -> \(ids[childPath] ?? sanitize(child.name));")
            emitEdges(parent: child, path: childPath, ids: ids, indent: indent, lines: &lines)
        }
    }

    private static func sanitize(_ raw: String) -> String {
        DOTHygiene.mangleID(raw, emptyPlaceholder: "n0")
    }

    private static func escape(_ s: String) -> String {
        DOTHygiene.escapeString(s)
    }

    private static func singleLine(_ s: String) -> String {
        DOTHygiene.singleLine(s)
    }
}
