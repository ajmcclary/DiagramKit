import Foundation

/// Render a `WardleyMapDiagram` as a coordinate table: each
/// component prints its label and (value, visibility) coordinates,
/// followed by a links block.
public func renderWardleyAscii(_ model: WardleyMapDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(title.count, 1)))
    }

    if !model.nodes.isEmpty {
        lines.append("Components:")
        for node in model.nodes {
            lines.append("  • \(node.label) [x=\(node.x), y=\(node.y)]")
        }
    }

    if !model.links.isEmpty {
        lines.append("Links:")
        for link in model.links {
            let label = (link.label?.isEmpty == false) ? " : \(link.label!)" : ""
            lines.append("  • \(link.source) → \(link.target)\(label)")
        }
    }

    return lines.joined(separator: "\n")
}
