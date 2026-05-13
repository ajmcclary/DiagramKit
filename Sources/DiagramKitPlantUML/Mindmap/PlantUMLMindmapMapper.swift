import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport

/// Converts a `PlantUMLMindmapTree` into a `MindmapDiagram` payload.
public struct PlantUMLMindmapMapper {

    public init() {}

    public func map(_ tree: PlantUMLMindmapTree) -> (model: MindmapDiagram, diagnostics: [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        for line in tree.unsupportedLines {
            diagnostics.append(DiagramDiagnostic(
                severity: .unsupported,
                message: "PlantUML mindmap line not yet supported: \(line)"
            ))
        }

        guard let root = tree.root else {
            return (MindmapDiagram.empty, diagnostics)
        }

        var nodeCounter = 0
        let mappedRoot = mapNode(root, level: 0, counter: &nodeCounter, isRoot: true)
        var flat: [MindmapNode] = []
        flatten(mappedRoot, into: &flat)
        let model = MindmapDiagram(root: mappedRoot, nodes: flat)
        return (model, diagnostics)
    }

    private func mapNode(
        _ source: PlantUMLMindmapNode,
        level: Int,
        counter: inout Int,
        isRoot: Bool
    ) -> MindmapNode {
        counter += 1
        let id = counter
        var children: [MindmapNode] = []
        for child in source.children {
            children.append(mapNode(child, level: level + 1, counter: &counter, isRoot: false))
        }
        return MindmapNode(
            id: id,
            nodeId: "mm\(id)",
            level: level,
            descr: source.label,
            type: .default,
            children: children,
            isRoot: isRoot
        )
    }

    private func flatten(_ node: MindmapNode, into list: inout [MindmapNode]) {
        list.append(node)
        for child in node.children {
            flatten(child, into: &list)
        }
    }
}
