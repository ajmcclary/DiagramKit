import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `treemap-beta` source from a `TreemapDiagram`.
///
/// Walks the forest (`model.nodes`) via the shared
/// `MermaidExportHelpers.emitIndentedTree` helper. Leaf nodes
/// (value present, no children) emit as `"name": value`; branch
/// nodes emit as `"name"` and recurse.
enum MermaidTreemapExport {

    static func emit(_ model: TreemapDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["treemap-beta"]
        let diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("    title \(singleLine(title))")
        }

        let treeLines = MermaidExportHelpers.emitIndentedTree(
            roots: model.nodes,
            indentUnit: "    ",
            childrenOf: { $0.children ?? [] },
            emitNode: { node, _ in
                let name = "\"\(node.name.replacingOccurrences(of: "\"", with: "\\\""))\""
                let isLeaf = (node.children?.isEmpty ?? true)
                if let value = node.value, isLeaf {
                    return ["\(name): \(formatNumber(value))"]
                }
                return [name]
            }
        )
        lines.append(contentsOf: treeLines)

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func formatNumber(_ value: Double) -> String {
        if value.rounded() == value && abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(value)
    }
}
