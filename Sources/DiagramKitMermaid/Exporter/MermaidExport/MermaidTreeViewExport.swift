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

        // Convention detection: synthetic `/` at level -1 means "Mermaid
        // multi-root container" — emit children as top-level entries. A
        // real root at level 0 (D2/DOT/PlantUML payloads) emits the root
        // itself as the first top-level entry. See TreeViewDiagram docs.
        let isSyntheticRoot = (model.root.name == "/" && model.root.level == -1)
        let topLevelRoots: [TreeViewNode] = isSyntheticRoot
            ? model.root.children
            : [model.root]

        let treeLines = MermaidExportHelpers.emitIndentedTree(
            roots: topLevelRoots,
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
        let suffix: String
        switch node.nodeType {
        case .directory:
            suffix = label.hasSuffix("/") ? "" : "/"
        case .file:
            suffix = ""
        }
        let head = "\(label)\(suffix)"

        // Emit an explicit `icon(...)` directive when the stored
        // iconId disagrees with `resolveIcon(name:, nodeType:)`.
        // Without this, suppressed-icon entries like `icon(none)`
        // would resolve back to the default `folder`/`file` icon on
        // re-parse.
        if let stored = node.iconId,
           stored != resolveIcon(name: node.name, nodeType: node.nodeType) {
            let directive = stored == "none" ? "icon(none)" : "icon(\(stored))"
            return "\(head) \(directive)"
        }
        return head
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
