import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `treeView-beta` source from a `TreeViewDiagram`.
///
/// Walks `model.root.children` (the visible top-level entries; `root`
/// itself is a synthetic container with name `"/"`). Directories
/// emit with a trailing `/`. Files emit as their bare name. Icon
/// ids are not re-emitted: the parser's `resolveIcon` derives the
/// same id from `(name, nodeType)` on re-parse. Indent = depth × 4
/// spaces; the parser stores `level` as the raw indent count and
/// rebuilds the tree from relative comparisons, so any consistent
/// indent unit suffices.
enum MermaidTreeViewExport {

    static func emit(_ model: TreeViewDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["treeView-beta"]
        let diagnostics: [DiagramDiagnostic] = []

        // The treeView grammar does not recognise a `title` keyword
        // nor accessibility metadata; skip them.
        _ = model.diagramTitle
        _ = model.accTitle
        _ = model.accDescr

        let treeLines = MermaidExportHelpers.emitIndentedTree(
            roots: model.root.children,
            indentUnit: "    ",
            childrenOf: { $0.children },
            emitNode: { node, _ in [renderLine(node)] }
        )
        lines.append(contentsOf: treeLines)

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func renderLine(_ node: TreeViewNode) -> String {
        let label = singleLine(node.name)
        switch node.nodeType {
        case .directory:
            return label.hasSuffix("/") ? label : "\(label)/"
        case .file:
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
