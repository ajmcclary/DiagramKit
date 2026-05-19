import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits PlantUML component-diagram syntax from an `ArchitectureDiagram`.
/// Default idiom for the `.architecture` payload in `PlantUMLExporter`.
enum PlantUMLComponentExport {

    static func emit(_ diagram: ArchitectureDiagram) throws -> DiagramExportResult {
        var lines: [String] = []
        lines.append("@startuml")
        if let title = diagram.diagramTitle, !title.isEmpty {
            lines.append("title \(singleLine(title))")
        }
        for service in diagram.services {
            lines.append("[\(service.id)]")
        }
        for edge in diagram.edges {
            if let label = edge.label, !label.isEmpty {
                lines.append("[\(edge.lhsId)] --> [\(edge.rhsId)] : \(escape(label))")
            } else {
                lines.append("[\(edge.lhsId)] --> [\(edge.rhsId)]")
            }
        }
        lines.append("@enduml")
        return DiagramExportResult(source: lines.joined(separator: "\n") + "\n", diagnostics: [])
    }

    private static func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }
}
