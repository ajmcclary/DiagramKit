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
        .journey,         // wave 1
        .timeline,        // wave 1
        .kanban,          // wave 1
        .mindmap,         // wave 1
        .treemap,         // wave 1
        .gitGraph,        // wave 1
        .xyChart,         // wave 2
        .quadrantChart,   // wave 2
        .requirement,     // wave 2
        .radar,           // wave 2
        .venn,            // wave 2
        .ishikawa,        // wave 2
        .treeView,        // wave 2
        .zenuml,          // wave 2
        .eventModeling,   // wave 2
        .block,           // wave 3
        .architecture,    // wave 3
        .wardleyBeta,     // wave 3
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
        case .journey(let model):
            result = try MermaidJourneyExport.emit(model)
        case .timeline(let model):
            result = try MermaidTimelineExport.emit(model)
        case .kanban(let model):
            result = try MermaidKanbanExport.emit(model)
        case .mindmap(let model):
            result = try MermaidMindmapExport.emit(model)
        case .treemap(let model):
            result = try MermaidTreemapExport.emit(model)
        case .gitGraph(let model):
            result = try MermaidGitGraphExport.emit(model)
        case .xyChart(let model):
            result = try MermaidXYChartExport.emit(model)
        case .quadrantChart(let model):
            result = try MermaidQuadrantExport.emit(model)
        case .requirement(let model):
            result = try MermaidRequirementExport.emit(model)
        case .radar(let model):
            result = try MermaidRadarExport.emit(model)
        case .venn(let model):
            result = try MermaidVennExport.emit(model)
        case .ishikawa(let model):
            result = try MermaidIshikawaExport.emit(model)
        case .treeView(let model):
            result = try MermaidTreeViewExport.emit(model)
        case .zenuml(let model):
            result = try MermaidZenUMLExport.emit(model)
        case .eventModeling(let model):
            result = try MermaidEventModelingExport.emit(model)
        case .block(let model):
            result = try MermaidBlockExport.emit(model)
        case .architecture(let model):
            result = try MermaidArchitectureExport.emit(model)
        case .wardleyBeta(let model):
            result = try MermaidWardleyExport.emit(model)
        }
        return Self.prependingFrontmatter(document, to: result)
    }

    /// Prefix the exported source with its frontmatter. A document parsed
    /// from Mermaid source gets its own preamble back byte for byte (only a
    /// title, theme or layout the document changed is edited in place), plus
    /// its `%%` comments and `click`/`link` lines exactly as written (owner
    /// rulings for canvas edits). Other documents get a block carrying the
    /// title, theme and layout, or nothing when all are absent. Key
    /// spelling matches what the frontmatter parser reads back (round-trip
    /// pinned by FrontmatterDocumentFieldTests).
    private static func prependingFrontmatter(
        _ document: DiagramDocument,
        to result: DiagramExportResult
    ) -> DiagramExportResult {
        guard !result.source.isEmpty else { return result }
        let title = document.title.flatMap { $0.isEmpty ? nil : singleLineTitle($0) }
        let theme = document.frontmatter?.theme.flatMap { $0.isEmpty ? nil : $0 }
        let layout = document.frontmatter?.layout.flatMap { $0.isEmpty ? nil : $0 }
        if let annotations = document.sourceAnnotations {
            let applied = _applyMermaidSourceAnnotationsReporting(
                result.source, annotations, title: title, theme: theme, layout: layout
            )
            let lost = applied.unplacedComments.map {
                DiagramDiagnostic.lossyTransform(.configDrop, message: "the comment \u{201C}\($0)\u{201D} followed a statement the diagram no longer has; it is not written")
            }
            return DiagramExportResult(source: applied.text, diagnostics: result.diagnostics + lost)
        }
        var lines: [String] = []
        if let title { lines.append("title: \(_yamlScalar(title))") }
        if theme != nil || layout != nil {
            lines.append("config:")
            if let theme { lines.append("  theme: \(_yamlScalar(theme))") }
            if let layout { lines.append("  layout: \(_yamlScalar(layout))") }
        }
        guard !lines.isEmpty else { return result }
        let frontmatter = "---\n" + lines.joined(separator: "\n") + "\n---\n"
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
