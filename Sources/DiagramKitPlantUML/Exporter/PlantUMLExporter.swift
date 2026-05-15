import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// PlantUML source-format exporter.
///
/// Emits valid PlantUML source. Coverage tracks the importer slices:
/// sequence (6A), class (6B). Additional families land with their
/// respective importer phases.
public struct PlantUMLExporter: DiagramExporter {
    public let name = "PlantUML"
    public let formatID = DiagramFormatID.plantuml

    /// Matches the current PlantUMLImporter family coverage.
    public let supportedDiagramTypes: Set<DiagramType> = [
        .sequenceDiagram,
        .classDiagram,
        .stateDiagram,
        .mindmap,
        .gantt,
        .c4,
    ]

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .sequenceDiagram(let model):
            return try PlantUMLSequenceExport.emit(model)
        case .classDiagram(let model):
            return try PlantUMLClassExport.emit(model)
        case .stateDiagram(let graph):
            return try PlantUMLStateExport.emit(graph)
        case .mindmap(let model):
            return try PlantUMLMindmapExport.emit(model)
        case .gantt(let model):
            return try PlantUMLGanttExport.emit(model)
        case .c4(let model):
            return try PlantUMLC4Export.emit(model)
        default:
            return DiagramExportResult(
                source: "",
                diagnostics: [
                    .featureDropped(
                        .diagramFamilyUnsupported,
                        message: "PlantUML export for '\(document.type.rawValue)' is not yet implemented"
                    )
                ]
            )
        }
    }
}
