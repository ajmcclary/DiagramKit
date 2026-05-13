import Foundation
import DiagramKitImport

/// Parses PlantUML mindmap bodies between `@startmindmap`/`@endmindmap`
/// or `@startwbs`/`@endwbs`.
///
/// Mindmap syntax is depth-prefixed:
/// ```
/// * Root
/// ** Child A
/// *** Grandchild A1
/// ** Child B
/// ```
///
/// The first marker character (`*`, `+`, or `-`) is the depth marker;
/// the repeat count is the depth (1 = root, 2 = first level under root,
/// etc.). The rest of the line — after the markers and one space — is
/// the node label.
public struct PlantUMLMindmapParser {

    public init() {}

    public func parse(_ body: String) -> PlantUMLMindmapTree {
        var tree = PlantUMLMindmapTree()
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)

        // Stack of (depth, indexInTree.flatNodes) — index into a flat node list.
        var stack: [(depth: Int, pathIndex: [Int])] = []

        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("'") { continue }

            guard let parsed = parseLine(trimmed) else {
                tree.unsupportedLines.append(trimmed)
                continue
            }

            // Pop stack to the parent depth (parsed.depth - 1).
            while let top = stack.last, top.depth >= parsed.depth {
                stack.removeLast()
            }

            let newNode = PlantUMLMindmapNode(label: parsed.label, depth: parsed.depth)

            if parsed.depth == 1 || stack.isEmpty {
                // Root or no parent — install as root if first, otherwise append as sibling.
                if tree.root == nil {
                    tree.root = newNode
                    stack.append((depth: parsed.depth, pathIndex: []))
                } else {
                    tree.unsupportedLines.append("Multiple roots: \(trimmed)")
                }
                continue
            }

            // Insert under current top-of-stack
            let parentPath = stack.last!.pathIndex
            insertChild(into: &tree.root!, at: parentPath, child: newNode)
            // The new node's path is parent's path + (parent's children.count - 1)
            let childCount = countChildren(in: tree.root!, at: parentPath)
            let newPath = parentPath + [childCount - 1]
            stack.append((depth: parsed.depth, pathIndex: newPath))
        }
        return tree
    }

    private struct LineComponents {
        let depth: Int
        let label: String
    }

    private func parseLine(_ line: String) -> LineComponents? {
        guard let firstChar = line.first else { return nil }
        let markerChar: Character
        switch firstChar {
        case "*", "+", "-": markerChar = firstChar
        default: return nil
        }
        var depth = 0
        var index = line.startIndex
        while index < line.endIndex, line[index] == markerChar {
            depth += 1
            index = line.index(after: index)
        }
        guard depth > 0 else { return nil }
        let label = line[index...].trimmingCharacters(in: .whitespaces)
        return LineComponents(depth: depth, label: label)
    }

    private func insertChild(
        into node: inout PlantUMLMindmapNode,
        at path: [Int],
        child: PlantUMLMindmapNode
    ) {
        if path.isEmpty {
            node.children.append(child)
            return
        }
        let head = path[0]
        let tail = Array(path.dropFirst())
        insertChild(into: &node.children[head], at: tail, child: child)
    }

    private func countChildren(in node: PlantUMLMindmapNode, at path: [Int]) -> Int {
        if path.isEmpty { return node.children.count }
        let head = path[0]
        let tail = Array(path.dropFirst())
        return countChildren(in: node.children[head], at: tail)
    }
}

public struct PlantUMLMindmapTree: Sendable {
    public var root: PlantUMLMindmapNode?
    public var unsupportedLines: [String]

    public init(root: PlantUMLMindmapNode? = nil, unsupportedLines: [String] = []) {
        self.root = root
        self.unsupportedLines = unsupportedLines
    }
}

public struct PlantUMLMindmapNode: Sendable {
    public var label: String
    public var depth: Int
    public var children: [PlantUMLMindmapNode]

    public init(label: String, depth: Int, children: [PlantUMLMindmapNode] = []) {
        self.label = label
        self.depth = depth
        self.children = children
    }
}
