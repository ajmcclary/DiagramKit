import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits a `MindmapDiagram` as D2 source.
///
/// Always emits `# diagramkit:family=mindmap` so re-import correctly
/// routes to the mindmap mapper (a directed tree alone is structurally
/// indistinguishable from a flowchart). Always emits
/// `# diagramkit:tree-root=<rootNodeId>` so multi-root foreign input
/// reconstructs to the original root.
///
/// Node shapes that don't have a native D2 mapping (`bang`,
/// `rounded-rect`) emit a `# diagramkit:mindmap-icon` marker plus a
/// `.lossyTransform(.shapeDowngrade, …)` diagnostic. Same-format
/// round-trip is lossless via marker recovery in `D2MindmapMapper`.
enum D2MindmapExport {

    static func emit(_ mindmap: MindmapDiagram, title: String?) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        lines.append(D2RecoveryMarker.emitFamily("mindmap"))
        if let t = title, !t.isEmpty {
            lines.append("# title: \(singleLine(t))")
        }
        guard let root = mindmap.root else {
            return DiagramExportResult(
                source: lines.joined(separator: "\n") + "\n",
                diagnostics: diagnostics
            )
        }
        lines.append(D2RecoveryMarker.emitTreeRoot(root.nodeId))

        emitNode(root, lines: &lines, diagnostics: &diagnostics)
        emitEdges(parent: root, lines: &lines)

        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    private static func emitNode(_ node: MindmapNode, lines: inout [String], diagnostics: inout [DiagramDiagnostic]) {
        let id = sanitize(node.nodeId)
        lines.append("\(id): \"\(escape(node.descr))\"")
        let (shapeName, needsMarker) = d2Shape(for: node.type)
        if let s = shapeName, s != "rectangle" {
            lines.append("\(id).shape: \(s)")
        }
        if needsMarker {
            lines.append(D2RecoveryMarker.emitMindmapIcon(nodeID: node.nodeId, iconKey: node.type.type2Str))
            diagnostics.append(.lossyTransform(
                .shapeDowngrade,
                message: "Mindmap node '\(node.nodeId)' shape '\(node.type.type2Str)' approximated; marker preserves shape"
            ))
        }
        for child in node.children { emitNode(child, lines: &lines, diagnostics: &diagnostics) }
    }

    private static func emitEdges(parent: MindmapNode, lines: inout [String]) {
        for child in parent.children {
            lines.append("\(sanitize(parent.nodeId)) -> \(sanitize(child.nodeId))")
            emitEdges(parent: child, lines: &lines)
        }
    }

    /// Returns the D2 shape name and whether a recovery marker is required.
    /// `rounded-rect` and `bang` have no native D2 equivalent; the
    /// shape name approximates and the marker preserves the original.
    private static func d2Shape(for type: MindmapNodeType) -> (name: String?, needsMarker: Bool) {
        switch type {
        case .default:     return (nil, false)
        case .rect:        return ("rectangle", false)
        case .roundedRect: return ("rectangle", true)
        case .circle:      return ("circle", false)
        case .cloud:       return ("cloud", false)
        case .hexagon:     return ("hexagon", false)
        case .bang:        return ("oval", true)
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
