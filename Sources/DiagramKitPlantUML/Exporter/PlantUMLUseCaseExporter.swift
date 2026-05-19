import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits PlantUML use-case syntax from a `ParsedGraphModel` payload.
///
/// Alternative idiom for `.flowchart`. The umbrella `PlantUMLExporter`
/// defaults `.flowchart` to activity syntax; useCase syntax is
/// reachable via `PlantUMLUseCaseExporter()` directly.
enum PlantUMLUseCaseExport {

    static func emit(_ model: ParsedGraphModel) throws -> DiagramExportResult {
        var lines: [String] = []
        lines.append("@startuml")
        if let title = model.accTitle, !title.isEmpty {
            lines.append("title \(singleLine(title))")
        }
        for entry in model.nodesInOrder {
            let node = entry.node
            lines.append("(\(node.label)) as \(node.id)")
        }
        for edge in model.edges {
            if let label = edge.label, !label.isEmpty {
                lines.append("\(edge.source) --> \(edge.target) : \(escape(label))")
            } else {
                lines.append("\(edge.source) --> \(edge.target)")
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

/// `DiagramExporter`-conforming wrapper for use-case emission.
public struct PlantUMLUseCaseExporter: DiagramExporter {
    public let name = "PlantUML (use case)"
    public let formatID = DiagramFormatID.plantuml
    public let supportedDiagramTypes: Set<DiagramType> = [.flowchart]

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .flowchart(let model):
            return try PlantUMLUseCaseExport.emit(model)
        default:
            return .unsupportedDiagram(formatName: name, type: document.type)
        }
    }
}
