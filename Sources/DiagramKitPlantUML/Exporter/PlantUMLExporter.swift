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

    /// Sequence + class — matches the current PlantUMLImporter coverage.
    public let supportedDiagramTypes: Set<DiagramType> = [
        .sequenceDiagram,
        .classDiagram,
    ]

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .sequenceDiagram(let model):
            return try PlantUMLSequenceExport.emit(model)
        case .classDiagram(let model):
            return try PlantUMLClassExport.emit(model)
        default:
            return DiagramExportResult(
                source: "",
                diagnostics: [
                    DiagramDiagnostic(
                        severity: .unsupported,
                        message: "PlantUML export for '\(document.type.rawValue)' is not yet implemented"
                    )
                ]
            )
        }
    }
}
