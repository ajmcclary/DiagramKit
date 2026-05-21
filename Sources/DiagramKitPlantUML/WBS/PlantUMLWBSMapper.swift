import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Converts a `PlantUMLWBSTree` into a `TreeViewDiagram` payload.
///
/// Assigns `TreeViewNode.id` in **DFS pre-order**: parent id is allocated
/// before any child id. This invariant is required by the
/// `treeViewNode*` recovery markers in `PlantUMLRecoveryMarker.Kind` —
/// markers reference nodes by their id, and cross-format markers only
/// apply correctly when all treeView mappers (including
/// Mermaid / D2 / DOT) follow the same pre-order assignment.
///
/// WBS-specific shape tokens (`<<box>>`) and color suffixes (`#LightBlue`)
/// have no slot on `TreeViewNode` — they surface as
/// `.featureDropped(.slotUnsupported, …)` diagnostics and are not
/// preserved across round-trip.
public struct PlantUMLWBSMapper {

    public init() {}

    public func map(
        _ tree: PlantUMLWBSTree
    ) -> (model: TreeViewDiagram, diagnostics: [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        for line in tree.unsupportedLines {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "PlantUML WBS line not yet supported: \(line)"
            ))
        }

        guard let root = tree.root else {
            return (TreeViewDiagram.empty, diagnostics)
        }

        var counter = 0
        var flat: [TreeViewNode] = []
        let mapped = mapNode(root, level: 0, counter: &counter, flat: &flat, diagnostics: &diagnostics)
        let diagram = TreeViewDiagram(
            root: mapped,
            nodes: flat,
            diagramTitle: tree.title
        )
        return (diagram, diagnostics)
    }

    private func mapNode(
        _ source: PlantUMLWBSNode,
        level: Int,
        counter: inout Int,
        flat: inout [TreeViewNode],
        diagnostics: inout [DiagramDiagnostic]
    ) -> TreeViewNode {
        let id = counter
        counter += 1

        if let shape = source.shape {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "PlantUML WBS shape variant <<\(shape)>> has no TreeViewNode slot"
            ))
        }
        if let color = source.color {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "PlantUML WBS color suffix #\(color) has no TreeViewNode slot"
            ))
        }

        // Reserve placeholder so flat[id] aligns with DFS pre-order.
        let placeholder = TreeViewNode(
            id: id,
            level: level,
            name: source.label,
            nodeType: source.children.isEmpty ? .file : .directory,
            children: []
        )
        flat.append(placeholder)

        var children: [TreeViewNode] = []
        for child in source.children {
            children.append(mapNode(
                child,
                level: level + 1,
                counter: &counter,
                flat: &flat,
                diagnostics: &diagnostics
            ))
        }
        var node = flat[id]
        node.children = children
        flat[id] = node
        return node
    }
}
