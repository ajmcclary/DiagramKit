import Foundation

/// Render an `ArchitectureDiagram` as a grouped list of services and
/// junctions plus an edge block.
public func renderArchitectureAscii(_ model: ArchitectureDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(title.count, 1)))
    }

    let groupsById = Dictionary(uniqueKeysWithValues: model.groups.map { ($0.id, $0) })

    func emitServicesUnder(groupId: String?, depth: Int) {
        let indent = String(repeating: "  ", count: depth)
        let services = model.services.filter { $0.parentGroupId == groupId }
        for service in services {
            let label = service.title ?? service.id
            lines.append("\(indent)• \(label)")
        }
        let junctions = model.junctions.filter { $0.parentGroupId == groupId }
        for junction in junctions {
            lines.append("\(indent)• junction \(junction.id)")
        }
        let childGroups = model.groups.filter { $0.parentGroupId == groupId }
        for group in childGroups {
            let label = group.title ?? group.id
            lines.append("\(indent)[\(label)]")
            emitServicesUnder(groupId: group.id, depth: depth + 1)
        }
    }

    emitServicesUnder(groupId: nil, depth: 0)
    _ = groupsById

    if !model.edges.isEmpty {
        lines.append("")
        for edge in model.edges {
            let label = (edge.label?.isEmpty == false) ? " : \(edge.label!)" : ""
            lines.append("\(edge.lhsId) → \(edge.rhsId)\(label)")
        }
    }

    return lines.joined(separator: "\n")
}
