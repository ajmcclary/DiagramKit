import Foundation
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Mermaid source-format exporter.
///
/// Emits valid Mermaid source from a `DiagramDocument`. Supported diagram
/// families grow per sub-slice. Unimplemented families return a
/// `.unsupported` diagnostic.
public struct MermaidExporter: DiagramExporter {
    public let name = "Mermaid"
    public let formatID = DiagramFormatID.mermaid

    /// Grows per sub-slice. Only families with active emit functions.
    public let supportedDiagramTypes: Set<DiagramType> = [
        .flowchart,       // 7A-P0
        .sequenceDiagram, // 7A-P0
        .classDiagram,    // 7A-P0
        .erDiagram,       // 7A-P0
        .c4,              // 7A-P0
        // .stateDiagram  — added in 7A-P1
        // .gantt         — added in 7A-P1
        // .mindmap       — added in 7A-P1
        // ... remaining families in 7A-P2 / Phase 10
    ]

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .flowchart(let model):
            return try MermaidFlowchartExport.emit(model)
        case .sequenceDiagram(let model):
            return try MermaidSequenceExport.emit(model)
        case .classDiagram(let model):
            return try MermaidClassExport.emit(model)
        case .erDiagram(let model):
            return try MermaidERExport.emit(model)
        case .c4(let model):
            return try MermaidC4Export.emit(model)
        default:
            return DiagramExportResult(
                source: "",
                diagnostics: [
                    DiagramDiagnostic(
                        severity: .unsupported,
                        message: "Mermaid export for '\(document.type.rawValue)' not yet implemented (7A-P1/7A-P2/Phase 10)"
                    )
                ]
            )
        }
    }
}
