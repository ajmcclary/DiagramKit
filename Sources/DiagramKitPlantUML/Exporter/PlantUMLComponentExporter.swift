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
        var diagnostics: [DiagramDiagnostic] = []
        lines.append("@startuml")
        if let title = diagram.diagramTitle, !title.isEmpty {
            lines.append("title \(singleLine(title))")
        }
        let deploymentKinds: Set<ArchitectureServiceKind> = [
            .node, .artifact, .database, .cloud, .frame, .folder,
            .package, .card, .queue, .stack, .storage, .agent,
            .actor, .boundary
        ]
        for service in diagram.services {
            if deploymentKinds.contains(service.kind) {
                diagnostics.append(.lossyTransform(
                    .shapeDowngrade,
                    message: "kind=\(service.kind.rawValue) downgraded to component for PlantUML component dialect"
                ))
            }
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
        return DiagramExportResult(source: lines.joined(separator: "\n") + "\n", diagnostics: diagnostics)
    }

    private static func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }
}
