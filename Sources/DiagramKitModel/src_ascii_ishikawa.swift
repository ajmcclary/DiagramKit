import Foundation

extension IshikawaNode: AsciiTreeNode {
    public var asciiLabel: String { text }
    public var asciiChildren: [IshikawaNode] { children }
}

public func renderIshikawaAscii(_ model: IshikawaDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(title.count, 1)))
    }
    guard let root = model.root else {
        return lines.joined(separator: "\n")
    }
    lines.append(renderAsciiTree(root: root))
    return lines.joined(separator: "\n")
}
