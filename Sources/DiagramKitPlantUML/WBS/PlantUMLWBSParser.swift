import Foundation

/// Parses PlantUML WBS bodies between `@startwbs`/`@endwbs`.
///
/// Syntax mirrors PlantUML mindmap indent prefixes (`*`, `+`, `-`,
/// repeated for depth). WBS-specific shape tokens (`<<box>>`) and color
/// suffixes (`#LightBlue`) are extracted onto AST node slots and surfaced
/// as `.featureDropped(.slotUnsupported, …)` diagnostics by
/// `PlantUMLWBSMapper`. The `title` line populates `PlantUMLWBSTree.title`.
public struct PlantUMLWBSParser {

    public init() {}

    public func parse(_ body: String) -> PlantUMLWBSTree {
        var tree = PlantUMLWBSTree()
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
        var stack: [(depth: Int, pathIndex: [Int])] = []

        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("'") { continue }

            if let title = stripPrefix("title ", trimmed) {
                tree.title = title
                continue
            }

            guard let parsed = parseLine(trimmed) else {
                tree.unsupportedLines.append(trimmed)
                continue
            }

            while let top = stack.last, top.depth >= parsed.depth {
                stack.removeLast()
            }

            let newNode = PlantUMLWBSNode(
                label: parsed.label,
                depth: parsed.depth,
                shape: parsed.shape,
                color: parsed.color
            )

            if parsed.depth == 1 || stack.isEmpty {
                if tree.root == nil {
                    tree.root = newNode
                    stack.append((depth: parsed.depth, pathIndex: []))
                } else {
                    tree.unsupportedLines.append("Multiple roots: \(trimmed)")
                }
                continue
            }

            let parentPath = stack.last!.pathIndex
            insertChild(into: &tree.root!, at: parentPath, child: newNode)
            let childCount = countChildren(in: tree.root!, at: parentPath)
            stack.append((depth: parsed.depth, pathIndex: parentPath + [childCount - 1]))
        }
        return tree
    }

    private struct LineComponents {
        let depth: Int
        let label: String
        let shape: String?
        let color: String?
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
        var remainder = String(line[index...]).trimmingCharacters(in: .whitespaces)
        let shape = extractShape(from: &remainder)
        let color = extractColor(from: &remainder)
        return LineComponents(
            depth: depth,
            label: remainder.trimmingCharacters(in: .whitespaces),
            shape: shape,
            color: color
        )
    }

    private func extractShape(from remainder: inout String) -> String? {
        // Match trailing `<<word>>` token.
        guard let range = remainder.range(
            of: #"\s*<<([A-Za-z_][A-Za-z0-9_]*)>>\s*$"#,
            options: .regularExpression
        ) else { return nil }
        let captured = remainder[range]
        let inner = captured.replacingOccurrences(
            of: #"\s*<<|>>\s*"#,
            with: "",
            options: .regularExpression
        )
        remainder.removeSubrange(range)
        return inner.isEmpty ? nil : inner
    }

    private func extractColor(from remainder: inout String) -> String? {
        // Match trailing `#name` or `#hexvalue` token after the label.
        guard let range = remainder.range(
            of: #"\s+#([A-Za-z0-9_]+)\s*$"#,
            options: .regularExpression
        ) else { return nil }
        let captured = remainder[range]
        let value = captured
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "#", with: "")
        remainder.removeSubrange(range)
        return value.isEmpty ? nil : value
    }

    private func stripPrefix(_ prefix: String, _ s: String) -> String? {
        guard s.hasPrefix(prefix) else { return nil }
        return String(s.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    private func insertChild(
        into node: inout PlantUMLWBSNode,
        at path: [Int],
        child: PlantUMLWBSNode
    ) {
        if path.isEmpty {
            node.children.append(child)
            return
        }
        insertChild(into: &node.children[path[0]], at: Array(path.dropFirst()), child: child)
    }

    private func countChildren(in node: PlantUMLWBSNode, at path: [Int]) -> Int {
        if path.isEmpty { return node.children.count }
        return countChildren(in: node.children[path[0]], at: Array(path.dropFirst()))
    }
}
