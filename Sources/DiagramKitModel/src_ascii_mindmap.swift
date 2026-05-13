import Foundation

extension MindmapNode: AsciiTreeNode {
    public var asciiLabel: String { descr }
    public var asciiChildren: [MindmapNode] { children }
}

public func renderMindmapAscii(_ model: MindmapDiagram) -> String {
    guard let root = model.root else {
        return model.diagramTitle ?? ""
    }
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(title.count, 1)))
    }
    lines.append(renderAsciiTree(root: root))
    return lines.joined(separator: "\n")
}
