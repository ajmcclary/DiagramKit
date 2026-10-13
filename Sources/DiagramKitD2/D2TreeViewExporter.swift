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

        if let first = topLevelRoots.first {
            lines.append(D2RecoveryMarker.emitTreeRoot(sanitize(first.name)))
        }
        for root in topLevelRoots {
            emitNode(root, lines: &lines, diagnostics: &diagnostics)
            emitEdges(parent: root, lines: &lines)
        }

        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    private static func emitNode(
        _ node: TreeViewNode,
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let id = sanitize(node.name)
        lines.append("\(id): \"\(escape(node.name))\"")
        if id != node.name {
            diagnostics.append(.lossyTransform(
                .idSanitization,
                message: "TreeView node name '\(node.name)' sanitized to D2 id '\(id)'"
            ))
        }
        for child in node.children { emitNode(child, lines: &lines, diagnostics: &diagnostics) }
    }

    private static func emitEdges(parent: TreeViewNode, lines: inout [String]) {
        for child in parent.children {
            lines.append("\(sanitize(parent.name)) -> \(sanitize(child.name))")
            emitEdges(parent: child, lines: &lines)
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
