import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `mindmap` source from a `MindmapDiagram`.
///
/// Walks the tree rooted at `model.root` and emits one node per line
/// indented by `depth * 2` spaces. Node shape is encoded via the
/// bracket pair that wraps the label.
enum MermaidMindmapExport {

    static func emit(_ model: MindmapDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["mindmap"]
        let diagnostics: [DiagramDiagnostic] = []

        guard let root = model.root else {
            let source = lines.joined(separator: "\n") + "\n"
            return DiagramExportResult(source: source, diagnostics: diagnostics)
        }

        emitNode(root, indentLevel: 1, lines: &lines)

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func emitNode(
        _ node: MindmapNode,
        indentLevel: Int,
        lines: inout [String]
    ) {
        let indent = String(repeating: " ", count: indentLevel * 2)
        lines.append("\(indent)\(formatNodeLabel(node))")
        for child in node.children {
            emitNode(child, indentLevel: indentLevel + 1, lines: &lines)
        }
    }

    private static func formatNodeLabel(_ node: MindmapNode) -> String {
        let label = singleLine(node.descr)
        let nid = node.nodeId
        switch node.type {
        case .roundedRect:
            return "\(nid)(\(label))"
        case .rect:
            return "\(nid)[\(label)]"
        case .circle:
            return "\(nid)((\(label)))"
        case .cloud:
            return "\(nid))\(label)("
        case .bang:
            return "\(nid)))\(label)(("
        case .hexagon:
            return "\(nid){{\(label)}}"
        case .`default`:
            // No-border default shape: emit just the descr, no
            // bracket pair.
            return label
        }
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
