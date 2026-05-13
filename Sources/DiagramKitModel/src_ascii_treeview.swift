import Foundation

extension TreeViewNode: AsciiTreeNode {
    public var asciiLabel: String { name }
    public var asciiChildren: [TreeViewNode] { children }
}

public func renderTreeViewAscii(_ model: TreeViewDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(title.count, 1)))
    }
    // The TreeView parser uses a synthetic level=-1 root; render children
    // as siblings under no shared root when that's the case.
    if model.root.level == -1, !model.root.children.isEmpty {
        for child in model.root.children {
            lines.append(renderAsciiTree(root: child))
        }
    } else {
        lines.append(renderAsciiTree(root: model.root))
    }
    return lines.joined(separator: "\n")
}
