import Foundation
import DiagramKitCommon
import DiagramKitModel

// MARK: - AsciiRenderContext

/// Shared context passed to every `AsciiDocumentRenderDescriptor`. Carries
/// only what the per-family renderers actually need: the resolved ASCII
/// theme and a lazy Mermaid-source provider that the source-fallback
/// descriptors invoke to reach `original_src_ascii_index
/// .renderMermaidASCIIWithDiagnostics`. Category A descriptors that
/// consume a typed payload directly ignore the provider, so the export
/// round-trip only fires for families that still need a string.
struct AsciiRenderContext: Sendable {
    let asciiTheme: original_src_ascii_index.AsciiTheme
    let mermaidSourceProvider: @Sendable () throws -> (source: String, diagnostics: [DiagramDiagnostic])
}

// MARK: - AsciiDocumentRenderDescriptor

/// Per-diagram-family document-aware ASCII rendering descriptor. Mirrors
/// `SVGRenderDescriptor` in shape — every entry consumes a parsed
/// `DiagramDocument` and emits an ASCII string paired with diagnostics.
/// The 22 Category A families (audit A1) use the `typed` factory and call
/// each family's typed `renderXxxAscii(model)` directly; the 6 remaining
/// families (sequence / class / ER / xychart / flowchart / state) use
/// `sourceFallback` to delegate to the legacy source-based renderer until
/// their bodies migrate to typed payloads.
struct AsciiDocumentRenderDescriptor: Sendable {
    let type: DiagramType
    let render: @Sendable (DiagramDocument, AsciiRenderContext) throws -> (String, [DiagramDiagnostic])
}

extension AsciiDocumentRenderDescriptor {
    /// Factory for descriptors that pattern-match a typed payload off
    /// `DiagramDocument`. On payload mismatch the descriptor throws
    /// `DiagramStructuralError.payloadMismatch(type)`, matching the SVG
    /// registry's contract at `SVGRenderRegistry.swift:34–51`.
    static func typed<Payload: Sendable>(
        _ type: DiagramType,
        _ extract: @Sendable @escaping (DiagramDocument) -> Payload?,
        render: @Sendable @escaping (Payload, AsciiRenderContext) throws -> (String, [DiagramDiagnostic])
    ) -> AsciiDocumentRenderDescriptor {
        AsciiDocumentRenderDescriptor(type: type) { document, context in
            guard let payload = extract(document) else {
                throw DiagramStructuralError.payloadMismatch(type)
            }
            return try render(payload, context)
        }
    }

    /// Factory for descriptors that still need a Mermaid source string.
    /// Invokes `context.mermaidSourceProvider` (which exports to Mermaid
    /// when the original input was non-Mermaid) and feeds the result to
    /// `original_src_ascii_index.renderMermaidASCIIWithDiagnostics`,
    /// preserving the legacy ASCII path verbatim for families whose
    /// renderers haven't migrated off source yet.
    static func sourceFallback(type: DiagramType) -> AsciiDocumentRenderDescriptor {
        AsciiDocumentRenderDescriptor(type: type) { _, context in
            let (mermaidSource, exportDiags) = try context.mermaidSourceProvider()
            let options = original_src_ascii_index.AsciiRenderOptions(theme: context.asciiTheme)
            let (text, renderDiags) = try original_src_ascii_index
                .renderMermaidASCIIWithDiagnostics(mermaidSource, options: options)
            return (text, exportDiags + renderDiags)
        }
    }
}

// MARK: - Payload extraction

/// File-private payload accessors on `DiagramDocument`. Match the
/// `if case let .X(...)` ceremony from `SVGRenderRegistry`'s
/// `PositionedGraph` extensions (`SVGRenderRegistry.swift:59–173`) so the
/// registry table reads as a flat `(type, accessor, renderer)` triple
/// per family.
private extension DiagramDocument {
    var pieChart: PieChart? {
        if case let .pie(chart) = typedPayload { return chart } else { return nil }
    }
    var journeyDiagram: JourneyDiagram? {
        if case let .journey(diagram) = typedPayload { return diagram } else { return nil }
    }
    var ganttDiagram: GanttDiagram? {
        if case let .gantt(diagram) = typedPayload { return diagram } else { return nil }
    }
    var quadrantChart: QuadrantChart? {
        if case let .quadrantChart(chart) = typedPayload { return chart } else { return nil }
    }
    var requirementDiagram: RequirementDiagram? {
        if case let .requirement(diagram) = typedPayload { return diagram } else { return nil }
    }
    var gitGraphDiagram: GitGraphDiagram? {
        if case let .gitGraph(diagram) = typedPayload { return diagram } else { return nil }
    }
    var mindmapDiagram: MindmapDiagram? {
        if case let .mindmap(diagram) = typedPayload { return diagram } else { return nil }
    }
    var timelineDiagram: TimelineDiagram? {
        if case let .timeline(diagram) = typedPayload { return diagram } else { return nil }
    }
    var sankeyDiagram: SankeyDiagram? {
        if case let .sankey(diagram) = typedPayload { return diagram } else { return nil }
    }
    var blockDiagram: BlockDiagram? {
        if case let .block(diagram) = typedPayload { return diagram } else { return nil }
    }
    var packetDiagram: PacketDiagram? {
        if case let .packet(diagram) = typedPayload { return diagram } else { return nil }
    }
    var kanbanDiagram: KanbanDiagram? {
        if case let .kanban(diagram) = typedPayload { return diagram } else { return nil }
    }
    var architectureDiagram: ArchitectureDiagram? {
        if case let .architecture(diagram) = typedPayload { return diagram } else { return nil }
    }
    var radarDiagram: RadarDiagram? {
        if case let .radar(diagram) = typedPayload { return diagram } else { return nil }
    }
    var treemapDiagram: TreemapDiagram? {
        if case let .treemap(diagram) = typedPayload { return diagram } else { return nil }
    }
    var vennDiagram: VennDiagram? {
        if case let .venn(diagram) = typedPayload { return diagram } else { return nil }
    }
    var ishikawaDiagram: IshikawaDiagram? {
        if case let .ishikawa(diagram) = typedPayload { return diagram } else { return nil }
    }
    var treeViewDiagram: TreeViewDiagram? {
        if case let .treeView(diagram) = typedPayload { return diagram } else { return nil }
    }
    var eventModelingDiagram: EventModelingDiagram? {
        if case let .eventModeling(diagram) = typedPayload { return diagram } else { return nil }
    }
    var wardleyMapDiagram: WardleyMapDiagram? {
        if case let .wardleyBeta(diagram) = typedPayload { return diagram } else { return nil }
    }
    var zenumlDiagram: ZenUMLDiagram? {
        if case let .zenuml(diagram) = typedPayload { return diagram } else { return nil }
    }
    var c4Diagram: C4Diagram? {
        if case let .c4(diagram) = typedPayload { return diagram } else { return nil }
    }
}

// MARK: - AsciiDocumentRenderRegistry

/// Canonical document-aware ASCII rendering dispatcher (audit A1). Routes
/// `DiagramDocument.type` to a per-family descriptor; mirrors the shape of
/// `SVGRenderRegistry`. All 28 supported families have an entry. 22 use
/// the typed-payload path and skip the Mermaid round-trip entirely; the
/// remaining 6 (sequence / class / ER / xychart / flowchart / state) use
/// `sourceFallback`, which keeps `AsciiRenderRegistry` (source-based) as
/// the documented compatibility layer per the audit's recommendation.
enum AsciiDocumentRenderRegistry {

    static let all: [DiagramType: AsciiDocumentRenderDescriptor] = [
        // MARK: Category A — typed payload, no re-parse, no Mermaid round-trip.

        .pie: .typed(.pie, { $0.pieChart }) { chart, _ in
            (renderPieAscii(chart), [])
        },
        .journey: .typed(.journey, { $0.journeyDiagram }) { diagram, _ in
            (renderJourneyAscii(diagram), [])
        },
        .gantt: .typed(.gantt, { $0.ganttDiagram }) { diagram, _ in
            (renderGanttAscii(diagram), [])
        },
        .quadrantChart: .typed(.quadrantChart, { $0.quadrantChart }) { chart, _ in
            (renderQuadrantAscii(chart), [])
        },
        .requirement: .typed(.requirement, { $0.requirementDiagram }) { diagram, _ in
            (renderRequirementAscii(diagram), [])
        },
        .gitGraph: .typed(.gitGraph, { $0.gitGraphDiagram }) { diagram, _ in
            (renderGitGraphAscii(diagram), [])
        },
        .mindmap: .typed(.mindmap, { $0.mindmapDiagram }) { diagram, _ in
            (renderMindmapAscii(diagram), [])
        },
        .timeline: .typed(.timeline, { $0.timelineDiagram }) { diagram, _ in
            (renderTimelineAscii(diagram), [])
        },
        .sankey: .typed(.sankey, { $0.sankeyDiagram }) { diagram, _ in
            (renderSankeyAscii(diagram), [])
        },
        .block: .typed(.block, { $0.blockDiagram }) { diagram, _ in
            (renderBlockAscii(diagram), [])
        },
        .packet: .typed(.packet, { $0.packetDiagram }) { diagram, _ in
            (renderPacketAscii(diagram), [])
        },
        .kanban: .typed(.kanban, { $0.kanbanDiagram }) { diagram, _ in
            (renderKanbanAscii(diagram), [])
        },
        .architecture: .typed(.architecture, { $0.architectureDiagram }) { diagram, _ in
            (renderArchitectureAscii(diagram), [])
        },
        .radar: .typed(.radar, { $0.radarDiagram }) { diagram, _ in
            (renderRadarAscii(diagram), [])
        },
        .treemap: .typed(.treemap, { $0.treemapDiagram }) { diagram, _ in
            (renderTreemapAscii(diagram), [])
        },
        .venn: .typed(.venn, { $0.vennDiagram }) { diagram, _ in
            (renderVennAscii(diagram), [])
        },
        .ishikawa: .typed(.ishikawa, { $0.ishikawaDiagram }) { diagram, _ in
            (renderIshikawaAscii(diagram), [])
        },
        .treeView: .typed(.treeView, { $0.treeViewDiagram }) { diagram, _ in
            (renderTreeViewAscii(diagram), [])
        },
        .eventModeling: .typed(.eventModeling, { $0.eventModelingDiagram }) { diagram, _ in
            (renderEventModelingAscii(diagram), [])
        },
        .wardleyBeta: .typed(.wardleyBeta, { $0.wardleyMapDiagram }) { diagram, _ in
            (renderWardleyAscii(diagram), [])
        },
        .zenuml: .typed(.zenuml, { $0.zenumlDiagram }) { diagram, _ in
            (renderZenUMLAscii(diagram), [])
        },
        .c4: .typed(.c4, { $0.c4Diagram }) { diagram, _ in
            (renderC4Ascii(diagram), [])
        },

        // MARK: Category B — source-based renderers; keep compat shim.

        .sequenceDiagram: .sourceFallback(type: .sequenceDiagram),
        .classDiagram:    .sourceFallback(type: .classDiagram),
        .erDiagram:       .sourceFallback(type: .erDiagram),
        .xyChart:         .sourceFallback(type: .xyChart),

        // MARK: Flowchart / state — inline `parseMermaid` + `drawGraph` path.

        .flowchart:    .sourceFallback(type: .flowchart),
        .stateDiagram: .sourceFallback(type: .stateDiagram),
    ]

    /// Look up the descriptor for `document.type` and execute it. Throws
    /// `DiagramError.notYetImplemented` if a family lacks an entry, to
    /// match the behavior of `SVGRenderRegistry.render` and the legacy
    /// `original_src_ascii_index.renderMermaidASCII` (`src_ascii_index.swift:430`).
    static func render(
        document: DiagramDocument,
        context: AsciiRenderContext
    ) throws -> (String, [DiagramDiagnostic]) {
        let type = document.type
        guard let descriptor = all[type] else {
            throw DiagramError.notYetImplemented(
                "ASCII rendering for \(type.rawValue)"
            )
        }
        return try descriptor.render(document, context)
    }
}
