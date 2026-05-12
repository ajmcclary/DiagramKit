import Foundation
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// PlantUML source-format exporter.
///
/// Emits valid PlantUML source, starting with sequence diagrams.
/// Additional families are gated by their Phase 6 importer slices.
public struct PlantUMLExporter: DiagramExporter {
    public let name = "PlantUML"
    public let formatID = DiagramFormatID.plantuml

    /// Sequence only — matches PlantUMLImporter's current coverage (6A).
    public let supportedDiagramTypes: Set<DiagramType> = [
        .sequenceDiagram,
        .c4,  // C4 via Structurizr importer path; round-trip in 7C
    ]

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .sequenceDiagram(let model):
            return try PlantUMLSequenceExport.emit(model)
        case .c4(let model):
            return try PlantUMLC4Export.emit(model)
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
