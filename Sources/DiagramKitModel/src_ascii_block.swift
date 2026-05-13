import Foundation

/// Render a `BlockDiagram` as a tabular list of blocks plus their
/// edges. Composite blocks indent their children one level.
public func renderBlockAscii(_ model: BlockDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(title.count, 1)))
    }

    func emit(blockId: String, depth: Int) {
        guard let node = model.blockDatabase[blockId] else { return }
        let indent = String(repeating: "  ", count: depth)
        let label = node.label.isEmpty ? blockId : node.label
        lines.append("\(indent)[\(label)]")
        for childId in node.children {
            emit(blockId: childId, depth: depth + 1)
        }
    }

    for rootChild in model.rootChildren {
        emit(blockId: rootChild, depth: 0)
    }

    if !model.edges.isEmpty {
        lines.append("")
        for edge in model.edges {
            let label = (edge.label?.isEmpty == false) ? " : \(edge.label!)" : ""
            lines.append("\(edge.start) → \(edge.end)\(label)")
        }
    }

    return lines.joined(separator: "\n")
}
