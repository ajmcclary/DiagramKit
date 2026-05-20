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
        lines.append("  \(DOTRecoveryMarker.emitTreeRoot(root.nodeId))")

        emitNode(root, indent: "  ", lines: &lines, diagnostics: &diagnostics)
        emitEdges(parent: root, indent: "  ", lines: &lines)

        lines.append("}")
        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    private static func emitNode(
        _ node: MindmapNode,
        indent: String,
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let id = sanitize(node.nodeId)
        let mapped = dotShape(for: node.type)
        var attrs: [String] = []
        attrs.append("label=\"\(escape(node.descr))\"")
        if let shape = mapped.shape { attrs.append("shape=\(shape)") }
        if let style = mapped.style { attrs.append("style=\(style)") }
        lines.append("\(indent)\(id) [\(attrs.joined(separator: ", "))];")

        if mapped.needsMarker {
            lines.append("\(indent)\(DOTRecoveryMarker.emitMindmapIcon(nodeID: node.nodeId, iconKey: node.type.type2Str))")
            diagnostics.append(.lossyTransform(
                .shapeDowngrade,
                message: "Mindmap node '\(node.nodeId)' shape '\(node.type.type2Str)' approximated; marker preserves shape"
            ))
        }
        for child in node.children {
            emitNode(child, indent: indent, lines: &lines, diagnostics: &diagnostics)
        }
    }

    private static func emitEdges(parent: MindmapNode, indent: String, lines: inout [String]) {
        for child in parent.children {
            lines.append("\(indent)\(sanitize(parent.nodeId)) -> \(sanitize(child.nodeId));")
            emitEdges(parent: child, indent: indent, lines: &lines)
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
        var out = ""
        for (i, ch) in raw.enumerated() {
            switch ch {
            case "a"..."z", "A"..."Z", "0"..."9", "_":
                if i == 0, ch.isNumber { out.append("_") }
                out.append(ch)
            case " ", "-", ".":
                out.append("_")
            default:
                break
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
