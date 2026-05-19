import Foundation
import DiagramKitCommon
import DiagramKitModel
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
        .gantt,           // 7A-P1 / Interactive Gantt resize
        .stateDiagram,    // REVIEW.md Medium #9
        .pie,             // wave 1
        .sankey,          // wave 1
        .packet,          // wave 1
        // .mindmap       — added in 7A-P1
        // ... remaining families in 7A-P2 / Phase 10
    ]

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        let result: DiagramExportResult
        switch document.payload {
        case .flowchart(let model):
            result = try MermaidFlowchartExport.emit(model)
        case .sequenceDiagram(let model):
            result = try MermaidSequenceExport.emit(model)
        case .classDiagram(let model):
            result = try MermaidClassExport.emit(model)
        case .erDiagram(let model):
            result = try MermaidERExport.emit(model)
        case .c4(let model):
            result = try MermaidC4Export.emit(model)
        case .gantt(let model):
            result = try MermaidGanttExport.emit(model)
        case .stateDiagram(let model):
            result = try MermaidStateExport.emit(model)
        case .pie(let model):
            result = try MermaidPieExport.emit(model)
        case .sankey(let model):
            result = try MermaidSankeyExport.emit(model)
        case .packet(let model):
            result = try MermaidPacketExport.emit(model)
        default:
            return .unsupportedDiagram(formatName: name, type: document.type)
        }
        return Self.prependingDocumentTitle(document.title, to: result)
    }

    private static func prependingDocumentTitle(
        _ title: String?,
        to result: DiagramExportResult
    ) -> DiagramExportResult {
        guard let title, !title.isEmpty, !result.source.isEmpty else {
            return result
        }
        let normalizedTitle = singleLineTitle(title)
        let frontmatter = "---\ntitle: \(normalizedTitle)\n---\n"
        return DiagramExportResult(
            source: frontmatter + result.source,
            diagnostics: result.diagnostics
        )
    }

    private static func singleLineTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .joined(separator: " ")
    }
}
