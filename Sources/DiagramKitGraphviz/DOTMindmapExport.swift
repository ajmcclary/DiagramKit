import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits a `MindmapDiagram` as DOT source.
///
/// Always emits family + tree-root markers so re-import routes
/// correctly and reconstructs the root. Node shapes that DOT can't
/// represent natively (`bang`) emit `mindmap-icon` markers plus
/// `.lossyTransform(.shapeDowngrade, …)` diagnostics.
enum DOTMindmapExport {

    static func emit(_ mindmap: MindmapDiagram, title: String?) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        lines.append("digraph G {")
        lines.append("  \(DOTRecoveryMarker.emitFamily("mindmap"))")
        if let t = title, !t.isEmpty {
            lines.append("  // title: \(singleLine(t))")
        }
        guard let root = mindmap.root else {
            lines.append("}")
            return DiagramExportResult(
                source: lines.joined(separator: "\n") + "\n",
                diagnostics: diagnostics
            )
        }
        // Mindmap node ids repeat (`A` under `A`); DOT ids must not.
        let ids = _uniqueTreeIDs(roots: [root], children: { $0.children }, base: { sanitize($0.nodeId) })
        lines.append("  \(DOTRecoveryMarker.emitTreeRoot(ids[[0]] ?? sanitize(root.nodeId)))")

        emitNode(root, path: [0], ids: ids, indent: "  ", lines: &lines, diagnostics: &diagnostics)
        emitEdges(parent: root, path: [0], ids: ids, indent: "  ", lines: &lines)

        lines.append("}")
        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    private static func emitNode(
        _ node: MindmapNode,
        path: [Int],
        ids: [[Int]: String],
        indent: String,
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let id = ids[path] ?? sanitize(node.nodeId)
        let mapped = dotShape(for: node.type)
        var attrs: [String] = []
        attrs.append("label=\"\(escape(node.descr))\"")
        if let shape = mapped.shape { attrs.append("shape=\(shape)") }
        if let style = mapped.style { attrs.append("style=\(style)") }
        lines.append("\(indent)\(id) [\(attrs.joined(separator: ", "))];")

        if mapped.needsMarker {
            lines.append("\(indent)\(DOTRecoveryMarker.emitMindmapIcon(nodeID: id, iconKey: node.type.type2Str))")
            diagnostics.append(.lossyTransform(
                .shapeDowngrade,
                message: "Mindmap node '\(node.nodeId)' shape '\(node.type.type2Str)' approximated; marker preserves shape"
            ))
        }
        for (i, child) in node.children.enumerated() {
            emitNode(child, path: path + [i], ids: ids, indent: indent, lines: &lines, diagnostics: &diagnostics)
        }
    }

    private static func emitEdges(
        parent: MindmapNode, path: [Int], ids: [[Int]: String], indent: String, lines: inout [String]
    ) {
        for (i, child) in parent.children.enumerated() {
            let childPath = path + [i]
            lines.append("\(indent)\(ids[path] ?? sanitize(parent.nodeId)) -> \(ids[childPath] ?? sanitize(child.nodeId));")
            emitEdges(parent: child, path: childPath, ids: ids, indent: indent, lines: &lines)
        }
    }

    private static func dotShape(for type: MindmapNodeType) -> (shape: String?, style: String?, needsMarker: Bool) {
        switch type {
        case .default:     return (nil, nil, false)
        case .rect:        return ("box", nil, false)
        case .roundedRect: return ("box", "rounded", false)
        case .circle:      return ("circle", nil, false)
        case .cloud:       return ("oval", "dashed", true)
        case .bang:        return ("oval", nil, true)
        case .hexagon:     return ("hexagon", nil, false)
        }
    }

    private static func sanitize(_ raw: String) -> String {
        DOTHygiene.mangleID(raw)
    }

    private static func escape(_ s: String) -> String {
        DOTHygiene.escapeString(s)
    }

    private static func singleLine(_ s: String) -> String {
        DOTHygiene.singleLine(s)
    }
}
