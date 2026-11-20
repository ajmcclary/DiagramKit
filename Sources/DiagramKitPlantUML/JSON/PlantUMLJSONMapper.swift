import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Converts a `PlantUMLJSONValue` into a `TreeViewDiagram`. Mapping:
///
///   - object ⇒ `.directory`, children keyed by their JSON key
///   - array  ⇒ `.directory`, children named `[0]`, `[1]`, …
///   - string ⇒ `.file`, description = `"literal"` (with quotes)
///   - number/bool/null ⇒ `.file`, description = literal text
///
/// Primitive documents (root is a string/number/bool/null) are wrapped
/// in a synthesized `.directory` node named `(root)` so
/// `TreeViewDiagram.root` (non-optional) always has structural context.
///
/// `TreeViewNode.id` is assigned in DFS pre-order (parent before children).
public struct PlantUMLJSONMapper {

    public init() {}

    public func map(
        _ value: PlantUMLJSONValue
    ) -> (model: TreeViewDiagram, diagnostics: [DiagramDiagnostic]) {
        var counter = 0
        var flat: [TreeViewNode] = []
        var diagnostics: [DiagramDiagnostic] = []

        let rootNode: TreeViewNode
        switch value {
        case .object, .array:
            rootNode = buildNode(
                name: "(root)",
                value: value,
                level: 0,
                counter: &counter,
                flat: &flat,
                diagnostics: &diagnostics
            )
        default:
            // Wrap primitive root in synthesized container.
            let containerId = counter
            counter += 1
            flat.append(TreeViewNode(id: containerId, level: 0, name: "(root)", nodeType: .directory))
            let child = buildLeaf(
                name: literalName(for: value),
                value: value,
                level: 1,
                counter: &counter,
                flat: &flat
            )
            var container = flat[containerId]
            container.children = [child]
            flat[containerId] = container
            rootNode = container
        }

        return (TreeViewDiagram(root: rootNode, nodes: flat), diagnostics)
    }

    /// Children deeper than `_maxParserNestingDepth` are dropped (once
    /// reported). The parser never produces such a tree; this bounds the
    /// recursion for a hand-built `PlantUMLJSONValue`.
    private func buildNode(
        name: String,
        value: PlantUMLJSONValue,
        level: Int,
        counter: inout Int,
        flat: inout [TreeViewNode],
        diagnostics: inout [DiagramDiagnostic]
    ) -> TreeViewNode {
        let id = counter
        counter += 1

        if level >= _maxParserNestingDepth, Self.hasChildren(value) {
            if !diagnostics.contains(where: { $0.message == Self.depthMessage }) {
                diagnostics.append(.featureDropped(.slotUnsupported, message: Self.depthMessage))
            }
            let truncated = TreeViewNode(id: id, level: level, name: name, nodeType: .directory)
            flat.append(truncated)
            return truncated
        }

        switch value {
        case .object(let pairs):
            flat.append(TreeViewNode(id: id, level: level, name: name, nodeType: .directory))
            var children: [TreeViewNode] = []
            for pair in pairs {
                children.append(buildNode(
                    name: pair.key,
                    value: pair.value,
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

        case .array(let elements):
            flat.append(TreeViewNode(id: id, level: level, name: name, nodeType: .directory))
            var children: [TreeViewNode] = []
            for (idx, val) in elements.enumerated() {
                children.append(buildNode(
                    name: "[\(idx)]",
                    value: val,
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

        case .string, .number, .bool, .null:
            let leaf = TreeViewNode(
                id: id,
                level: level,
                name: name,
                nodeType: .file,
                description: literalDescription(for: value)
            )
            flat.append(leaf)
            return leaf
        }
    }

    private static let depthMessage =
        "PlantUML @startjson is nested deeper than \(_maxParserNestingDepth) levels; deeper values dropped"

    private static func hasChildren(_ value: PlantUMLJSONValue) -> Bool {
        switch value {
        case .object(let pairs): return !pairs.isEmpty
        case .array(let elements): return !elements.isEmpty
        case .string, .number, .bool, .null: return false
        }
    }

    private func buildLeaf(
        name: String,
        value: PlantUMLJSONValue,
        level: Int,
        counter: inout Int,
        flat: inout [TreeViewNode]
    ) -> TreeViewNode {
        let id = counter
        counter += 1
        let leaf = TreeViewNode(
            id: id,
            level: level,
            name: name,
            nodeType: .file,
            description: literalDescription(for: value)
        )
        flat.append(leaf)
        return leaf
    }

    private func literalName(for value: PlantUMLJSONValue) -> String {
        switch value {
        case .string: return "string"
        case .number: return "number"
        case .bool:   return "bool"
        case .null:   return "null"
        case .object, .array: return "(root)"
        }
    }

    private func literalDescription(for value: PlantUMLJSONValue) -> String {
        switch value {
        case .string(let s): return "\"\(s)\""
        case .number(let n): return n
        case .bool(let b):   return b ? "true" : "false"
        case .null:          return "null"
        case .object, .array: return ""
        }
    }
}
