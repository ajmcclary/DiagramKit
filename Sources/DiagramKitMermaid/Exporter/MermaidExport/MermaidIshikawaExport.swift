import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `ishikawa-beta` source from an `IshikawaDiagram`.
///
/// Walks the root tree and emits each node on its own line with
/// indentation = depth × 4 spaces. Reuses the Wave 1
/// `MermaidExportHelpers.emitIndentedTree` helper now that it has a
/// third tree caller.
enum MermaidIshikawaExport {

    static func emit(_ model: IshikawaDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["ishikawa-beta"]
        let diagnostics: [DiagramDiagnostic] = []

        // The Ishikawa parser does not recognise a `title` keyword and
        // auto-sets `diagramTitle = root.text`. Re-emitting a title
        // line would be re-parsed as another node. Accessibility
        // metadata is also not recognised by this grammar; skip both.
        _ = model.diagramTitle
        _ = model.accTitle
        _ = model.accDescr

        if let root = model.root {
            let treeLines = MermaidExportHelpers.emitIndentedTree(
                roots: [root],
                indentUnit: "    ",
                childrenOf: { $0.children },
                emitNode: { node, _ in [singleLine(node.text)] }
            )
            lines.append(contentsOf: treeLines)
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
