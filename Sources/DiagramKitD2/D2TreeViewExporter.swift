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
        lines.append(D2RecoveryMarker.emitTreeRoot(tree.root.name))

        emitNode(tree.root, lines: &lines, diagnostics: &diagnostics)
        emitEdges(parent: tree.root, lines: &lines)

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
        return out.isEmpty ? "node" : out
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
