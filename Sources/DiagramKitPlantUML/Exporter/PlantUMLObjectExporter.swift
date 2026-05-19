import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits PlantUML object-diagram syntax from a `ClassDiagram` payload.
///
/// Alternative idiom for `.classDiagram`. The umbrella `PlantUMLExporter`
/// defaults `.classDiagram` to class syntax; object syntax is reachable
/// via `PlantUMLObjectExporter()` directly.
enum PlantUMLObjectExport {

    static func emit(_ model: ClassDiagram) throws -> DiagramExportResult {
        var lines: [String] = []
        lines.append("@startuml")
        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("title \(singleLine(title))")
        }
        for node in model.classes {
            if node.attributes.isEmpty {
                lines.append("object \(node.id)")
            } else {
                lines.append("object \(node.id) {")
                for member in node.attributes {
                    lines.append("  \(member.id)")
                }
                lines.append("}")
            }
        }
        for rel in model.relationships {
            let arrow = arrowFor(endpoint: rel.relation)
            if !rel.title.isEmpty {
                lines.append("\(rel.id1) \(arrow) \(rel.id2) : \(escape(rel.title))")
            } else {
                lines.append("\(rel.id1) \(arrow) \(rel.id2)")
            }
        }
        lines.append("@enduml")
        return DiagramExportResult(source: lines.joined(separator: "\n") + "\n", diagnostics: [])
    }

    private static func arrowFor(endpoint: ClassRelationEndpoint) -> String {
        if endpoint.lineType == ClassLineType.dotted.rawValue {
            return "..>"
        }
        switch endpoint.type2 {
        case ClassRelationType.composition.rawValue: return "*--"
        case ClassRelationType.aggregation.rawValue: return "o--"
        case ClassRelationType.dependency.rawValue:  return "..>"
        default: return "-->"
        }
    }

    private static func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }
}

/// `DiagramExporter`-conforming wrapper for object-diagram emission.
public struct PlantUMLObjectExporter: DiagramExporter {
    public let name = "PlantUML (object)"
    public let formatID = DiagramFormatID.plantuml
    public let supportedDiagramTypes: Set<DiagramType> = [.classDiagram]

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .classDiagram(let model):
            return try PlantUMLObjectExport.emit(model)
        default:
            return .unsupportedDiagram(formatName: name, type: document.type)
        }
    }
}
