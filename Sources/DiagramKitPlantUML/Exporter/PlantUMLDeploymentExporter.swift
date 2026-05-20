import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits PlantUML deployment-diagram syntax from an `ArchitectureDiagram`.
/// Used by `PlantUMLExporter` when the document contains deployment-kind
/// services. Same-format round-trip is lossless via comment-encoded
/// recovery markers (wired in Task 13).
enum PlantUMLDeploymentExport {

    static func emit(_ diagram: ArchitectureDiagram) throws -> DiagramExportResult {
        var lines: [String] = []
        lines.append("@startuml")
        if let title = diagram.diagramTitle, !title.isEmpty {
            lines.append("title \(singleLine(title))")
        }
        let rootGroups = diagram.groups.filter { $0.parentGroupId == nil }
        let rootServices = diagram.services.filter { $0.parentGroupId == nil }
        for group in rootGroups {
            emitGroup(group, depth: 0, diagram: diagram, lines: &lines)
        }
        for service in rootServices {
            lines.append(serviceLine(service, indent: ""))
        }
        for edge in diagram.edges {
            lines.append(edgeLine(edge))
        }
        lines.append("@enduml")
        return DiagramExportResult(source: lines.joined(separator: "\n") + "\n", diagnostics: [])
    }

    private static func emitGroup(
        _ group: ArchitectureGroup, depth: Int,
        diagram: ArchitectureDiagram,
        lines: inout [String]
    ) {
        let indent = String(repeating: "  ", count: depth)
        // Group keyword defaults to `node` for now. Task 13 reads a
        // deployment-group-kind recovery marker to restore the original.
        let keyword = "node"
        let label = group.title.map { " \"\($0)\" " } ?? " "
        lines.append("\(indent)\(keyword)\(label)as \(group.id) {")
        let childGroups = diagram.groups.filter { $0.parentGroupId == group.id }
        for child in childGroups {
            emitGroup(child, depth: depth + 1, diagram: diagram, lines: &lines)
        }
        let childServices = diagram.services.filter { $0.parentGroupId == group.id }
        let childIndent = String(repeating: "  ", count: depth + 1)
        for service in childServices {
            lines.append(serviceLine(service, indent: childIndent))
        }
        lines.append("\(indent)}")
    }

    private static func serviceLine(_ service: ArchitectureService, indent: String) -> String {
        let keyword = service.kind.plantUMLDeploymentKeyword
        if let title = service.title, !title.isEmpty {
            return "\(indent)\(keyword) \"\(title)\" as \(service.id)"
        }
        return "\(indent)\(keyword) \(service.id)"
    }

    private static func edgeLine(_ edge: ArchitectureEdge) -> String {
        let arrow = "-->"
        if let label = edge.label, !label.isEmpty {
            return "\(edge.lhsId) \(arrow) \(edge.rhsId) : \(escape(label))"
        }
        return "\(edge.lhsId) \(arrow) \(edge.rhsId)"
    }

    private static func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }
}

extension ArchitectureServiceKind {
    fileprivate var plantUMLDeploymentKeyword: String {
        switch self {
        case .service:   return "node"
        case .component: return "component"
        case .interface: return "interface"
        case .node:      return "node"
        case .artifact:  return "artifact"
        case .database:  return "database"
        case .cloud:     return "cloud"
        case .frame:     return "frame"
        case .folder:    return "folder"
        case .package:   return "package"
        case .card:      return "card"
        case .queue:     return "queue"
        case .stack:     return "stack"
        case .storage:   return "storage"
        case .agent:     return "agent"
        case .actor:     return "actor"
        case .boundary:  return "boundary"
        }
    }
}
