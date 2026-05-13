import Foundation

/// Render a `KanbanDiagram` as columns of tickets. Sections become
/// top-level headers; non-section nodes are listed under their
/// parent section.
public func renderKanbanAscii(_ model: KanbanDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(title.count, 1)))
    }

    let nodesById = Dictionary(uniqueKeysWithValues: model.nodes.map { ($0.id, $0) })
    _ = nodesById

    for section in model.sections {
        lines.append("[\(section.label.isEmpty ? section.id : section.label)]")
        let children = model.nodes.filter { $0.parentId == section.id }
        for child in children {
            let assignee = child.assigned.map { " — assigned: \($0)" } ?? ""
            let priority = child.priority.map { " [\($0)]" } ?? ""
            lines.append("  • \(child.label.isEmpty ? child.id : child.label)\(priority)\(assignee)")
        }
    }
    return lines.joined(separator: "\n")
}
