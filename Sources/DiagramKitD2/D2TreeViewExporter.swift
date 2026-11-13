import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits a `TreeViewDiagram` as D2 source.
///
/// Always emits family + tree-root markers. TreeView has no per-node
/// shape vocabulary so no `mindmap-icon` markers are involved. The
/// TreeViewNode `name` field doubles as the D2 source identifier;
/// names that get sanitized emit a `.lossyTransform(.idSanitization)`
/// diagnostic.
enum D2TreeViewExport {

    static func emit(_ tree: TreeViewDiagram, title: String?) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        lines.append(D2RecoveryMarker.emitFamily("treeView"))
        if let t = title, !t.isEmpty {
            lines.append("# title: \(singleLine(t))")
        }

        // Convention detection: synthetic `/` at level -1 means "Mermaid
        // multi-root container". Emit each child as a top-level forest
        // declaration; D2 supports multiple zero-in-degree nodes natively.
        // The tree-root marker fires on the FIRST child only (ordering
        // hint for the importer; see D2TreeViewMapper multi-root path).
        let isSyntheticRoot = (tree.root.name == "/" && tree.root.level == -1)
        let topLevelRoots: [TreeViewNode] = isSyntheticRoot ? tree.root.children : [tree.root]

        // Names repeat in ordinary trees (two `index.ts`, a directory
        // holding a same-named entry); ids must not.
        let ids = _uniqueTreeIDs(roots: topLevelRoots, children: { $0.children }, base: { sanitize($0.name) })
        if !topLevelRoots.isEmpty, let first = ids[[0]] {
            lines.append(D2RecoveryMarker.emitTreeRoot(first))
        }
        for (i, root) in topLevelRoots.enumerated() {
            emitNode(root, path: [i], ids: ids, lines: &lines, diagnostics: &diagnostics)
            emitEdges(parent: root, path: [i], ids: ids, lines: &lines)
        }

        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    private static func emitNode(
        _ node: TreeViewNode,
        path: [Int],
        ids: [[Int]: String],
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let id = ids[path] ?? sanitize(node.name)
        lines.append("\(id): \"\(escape(node.name))\"")
        if sanitize(node.name) != node.name {
            diagnostics.append(.lossyTransform(
                .idSanitization,
                message: "TreeView node name '\(node.name)' sanitized to D2 id '\(id)'"
            ))
        }
        for (i, child) in node.children.enumerated() {
            emitNode(child, path: path + [i], ids: ids, lines: &lines, diagnostics: &diagnostics)
        }
    }

    private static func emitEdges(parent: TreeViewNode, path: [Int], ids: [[Int]: String], lines: inout [String]) {
        for (i, child) in parent.children.enumerated() {
            let childPath = path + [i]
            lines.append("\(ids[path] ?? sanitize(parent.name)) -> \(ids[childPath] ?? sanitize(child.name))")
            emitEdges(parent: child, path: childPath, ids: ids, lines: &lines)
        }
    }

    private static func sanitize(_ raw: String) -> String {
        D2Hygiene.mangleID(raw)
    }

    private static func escape(_ s: String) -> String {
        D2Hygiene.escapeString(s)
    }

    private static func singleLine(_ s: String) -> String {
        D2Hygiene.singleLine(s)
    }
}
