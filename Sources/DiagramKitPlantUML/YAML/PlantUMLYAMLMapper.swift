import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Converts `PlantUMLYAMLParseResult` into a `TreeViewDiagram`.
/// Conventions mirror `PlantUMLJSONMapper`:
///   - mapping  ⇒ `.directory` with string keys
///   - sequence ⇒ `.directory` with `[i]` keys
///   - scalar   ⇒ `.file` with raw token in description
///
/// Scalar document roots wrap in a synthesized `(root)` container.
/// `unsupportedFeatures` from the parser surface as
/// `.featureDropped(.slotUnsupported, …)` diagnostics.
/// `TreeViewNode.id` is assigned in DFS pre-order.
public struct PlantUMLYAMLMapper {

    public init() {}

    public func map(
        _ result: PlantUMLYAMLParseResult
    ) -> (model: TreeViewDiagram, diagnostics: [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        for feature in result.unsupportedFeatures {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: feature
            ))
        }

        var counter = 0
        var flat: [TreeViewNode] = []

        let rootNode: TreeViewNode
        switch result.value {
        case .mapping, .sequence:
            rootNode = buildNode(
                name: "(root)",
                value: result.value,
                level: 0,
                counter: &counter,
                flat: &flat
            )
        case .scalar(let raw):
            let containerId = counter
            counter += 1
            flat.append(TreeViewNode(id: containerId, level: 0, name: "(root)", nodeType: .directory))
            let leafId = counter
            counter += 1
            let leaf = TreeViewNode(
                id: leafId,
                level: 1,
                name: "scalar",
                nodeType: .file,
                description: raw
            )
            flat.append(leaf)
            var container = flat[containerId]
            container.children = [leaf]
            flat[containerId] = container
            rootNode = container
        }

        return (TreeViewDiagram(root: rootNode, nodes: flat), diagnostics)
    }

    private func buildNode(
        name: String,
        value: PlantUMLYAMLValue,
        level: Int,
        counter: inout Int,
        flat: inout [TreeViewNode]
    ) -> TreeViewNode {
        let id = counter
        counter += 1

        switch value {
        case .mapping(let pairs):
            flat.append(TreeViewNode(id: id, level: level, name: name, nodeType: .directory))
            var children: [TreeViewNode] = []
            for pair in pairs {
                children.append(buildNode(
                    name: pair.key, value: pair.value, level: level + 1, counter: &counter, flat: &flat
                ))
            }
            var node = flat[id]
            node.children = children
            flat[id] = node
            return node

        case .sequence(let elements):
            flat.append(TreeViewNode(id: id, level: level, name: name, nodeType: .directory))
            var children: [TreeViewNode] = []
            for (idx, val) in elements.enumerated() {
                children.append(buildNode(
                    name: "[\(idx)]", value: val, level: level + 1, counter: &counter, flat: &flat
                ))
            }
            var node = flat[id]
            node.children = children
            flat[id] = node
            return node

        case .scalar(let raw):
            let leaf = TreeViewNode(
                id: id, level: level, name: name, nodeType: .file, description: raw
            )
            flat.append(leaf)
            return leaf
        }
    }
}
