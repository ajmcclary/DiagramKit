// Shared ASCII tree rendering utility.
//
// Used by mindmap, treeView, and Ishikawa renderers to draw recursive
// node hierarchies with `├── child` / `└── child` connectors.
import Foundation
import DiagramKitCommon

public protocol AsciiTreeNode {
    var asciiLabel: String { get }
    var asciiChildren: [Self] { get }
}

public enum AsciiTreeStyle {
    case unicode
    case asciiSafe
}

public func renderAsciiTree<Node: AsciiTreeNode>(
    root: Node,
    style: AsciiTreeStyle = .unicode
) -> String {
    var lines: [String] = []
    appendNode(root, prefix: "", isTail: true, isRoot: true, style: style, depth: 0, lines: &lines)
    return lines.joined(separator: "\n")
}

private func appendNode<Node: AsciiTreeNode>(
    _ node: Node,
    prefix: String,
    isTail: Bool,
    isRoot: Bool,
    style: AsciiTreeStyle,
    depth: Int,
    lines: inout [String]
) {
    let branch: String
    let cont: String
    switch (style, isTail) {
    case (.unicode, true):    branch = "└── "; cont = "    "
    case (.unicode, false):   branch = "├── "; cont = "│   "
    case (.asciiSafe, true):  branch = "`-- "; cont = "    "
    case (.asciiSafe, false): branch = "|-- "; cont = "|   "
    }
    if isRoot {
        lines.append(node.asciiLabel)
    } else {
        lines.append(prefix + branch + node.asciiLabel)
    }
    guard _recursionGuard(depth: depth, location: "ascii.appendNode") else {
        return
    }
    let nextPrefix = isRoot ? "" : prefix + cont
    let children = node.asciiChildren
    for (idx, child) in children.enumerated() {
        appendNode(
            child,
            prefix: nextPrefix,
            isTail: idx == children.count - 1,
            isRoot: false,
            style: style,
            depth: depth + 1,
            lines: &lines
        )
    }
}
