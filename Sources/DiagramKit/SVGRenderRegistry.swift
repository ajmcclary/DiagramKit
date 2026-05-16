import Foundation
import DiagramKitModel
import DiagramKitCommon

// MARK: - SVGRenderDescriptor

/// Per-diagram-family positioned-SVG rendering descriptor. Every family
/// registered in `SVGRenderRegistry.all` carries a closure that consumes
/// a pre-laid-out `PositionedGraph` and emits an SVG string. The legacy
/// source-based `render` closure (which fanned out to 27 `_render*SvgCase`
/// helpers that parsed + laid out inline) was retired in Phase 2 (audit
/// A4); construction now flows uniformly through
/// `DiagramPipeline.parse` → `GraphLayout` → here.
struct SVGRenderDescriptor: Sendable {
    let type: DiagramType
    let renderPositioned: @Sendable (
        _ positioned: PositionedGraph,
        _ diagramId: String?,
        _ colors: DiagramColors,
        _ font: String,
        _ transparent: Bool
    ) throws -> String
}

// MARK: - Typed factory

extension SVGRenderDescriptor {
    /// Factory for descriptors whose render closure operates on a typed
    /// payload extracted from `PositionedGraph`. The `extract` key path
    /// resolves the family-specific payload; on payload mismatch the
    /// descriptor throws `DiagramStructuralError.payloadMismatch(type)`.
    /// Eliminates the per-entry `guard case let .X(...)` boilerplate
    /// (audit A7).
    static func typed<Payload: Sendable>(
        _ type: DiagramType,
        _ extract: @Sendable @escaping (PositionedGraph) -> Payload?,
        render: @Sendable @escaping (
            _ payload: Payload,
            _ diagramId: String?,
            _ colors: DiagramColors,
            _ font: String,
            _ transparent: Bool
        ) throws -> String
    ) -> SVGRenderDescriptor {
        SVGRenderDescriptor(type: type) { positioned, diagramId, colors, font, transparent in
            guard let payload = extract(positioned) else {
                throw DiagramStructuralError.payloadMismatch(type)
            }
            return try render(payload, diagramId, colors, font, transparent)
        }
    }
}

// MARK: - Payload extraction

/// File-private payload accessors that consolidate the
/// `if case let .X(...) = content` ceremony so the descriptor table reads
/// as a flat `(type, payload accessor, renderer)` triple per family.
private extension PositionedGraph {
    var pieChart: PositionedPieChart? {
        if case let .pie(chart) = content { return chart } else { return nil }
    }
    var xyChart: PositionedXYChart? {
        if case let .xyChart(chart) = content { return chart } else { return nil }
    }
    var journeyDiagram: PositionedJourneyDiagram? {
        if case let .journey(diagram) = content { return diagram } else { return nil }
    }
    var ganttDiagram: PositionedGanttDiagram? {
        if case let .gantt(data) = content { return data } else { return nil }
    }
    var quadrantChart: PositionedQuadrantChart? {
        if case let .quadrantChart(chart) = content { return chart } else { return nil }
    }
    var requirementDiagram: PositionedRequirementDiagram? {
        if case let .requirement(data) = content { return data } else { return nil }
    }
    var gitGraphDiagram: PositionedGitGraphDiagram? {
        if case let .gitGraph(data) = content { return data } else { return nil }
    }
    var mindmapDiagram: PositionedMindmapDiagram? {
        if case let .mindmap(data) = content { return data } else { return nil }
    }
    var timelineDiagram: PositionedTimelineDiagram? {
        if case let .timeline(data) = content { return data } else { return nil }
    }
    var sankeyDiagram: PositionedSankeyDiagram? {
        if case let .sankey(diagram) = content { return diagram } else { return nil }
    }
    var blockDiagram: PositionedBlockDiagram? {
        if case let .block(data) = content { return data } else { return nil }
    }
    var packetDiagram: PositionedPacketDiagram? {
        if case let .packet(data) = content { return data } else { return nil }
    }
    var kanbanDiagram: PositionedKanbanDiagram? {
        if case let .kanban(data) = content { return data } else { return nil }
    }
    var architectureDiagram: PositionedArchitectureDiagram? {
        if case let .architecture(data) = content { return data } else { return nil }
    }
    var radarDiagram: PositionedRadarDiagram? {
        if case let .radar(diagram) = content { return diagram } else { return nil }
    }
    var treemapDiagram: PositionedTreemapDiagram? {
        if case let .treemap(data) = content { return data } else { return nil }
    }
    var vennDiagram: PositionedVennDiagram? {
        if case let .venn(data) = content { return data } else { return nil }
    }
    var ishikawaDiagram: PositionedIshikawaDiagram? {
        if case let .ishikawa(data) = content { return data } else { return nil }
    }
    var treeViewDiagram: PositionedTreeViewDiagram? {
        if case let .treeView(data) = content { return data } else { return nil }
    }
    var eventModelingDiagram: PositionedEventModelingDiagram? {
        if case let .eventModeling(data) = content { return data } else { return nil }
    }
    var wardleyMapDiagram: PositionedWardleyMapDiagram? {
        if case let .wardleyBeta(diagram) = content { return diagram } else { return nil }
    }
    var c4Diagram: PositionedC4Diagram? {
        if case let .c4(diagram) = content { return diagram } else { return nil }
    }
    var zenumlDiagram: PositionedZenUMLDiagram? {
        if case let .zenuml(data) = content { return data } else { return nil }
    }

    /// Reconstructs `PositionedSequenceDiagram` from the multi-arg enum case
    /// so the registry entry can use the typed-descriptor factory.
    var sequenceDiagramStruct: PositionedSequenceDiagram? {
        guard case let .sequenceDiagram(
            actors, messages, blocks, lifelines, activations, notes, boxes,
            bottomActors, rectHighlights, title, accTitle, accDescr
        ) = content else { return nil }
        return PositionedSequenceDiagram(
            width: width, height: height,
            actors: actors, lifelines: lifelines, messages: messages,
            activations: activations, blocks: blocks, notes: notes,
            boxes: boxes, bottomActors: bottomActors,
            rectHighlights: rectHighlights, title: title,
            accTitle: accTitle, accDescr: accDescr
        )
    }

    /// Reconstructs `PositionedClassDiagram` for the typed-descriptor factory.
    var classDiagramStruct: PositionedClassDiagram? {
        guard case let .classDiagram(
            classes, relationships, namespaces, notes, accTitle, accDescr, diagramTitle
        ) = content else { return nil }
        return PositionedClassDiagram(
            width: width, height: height,
            classes: classes, relationships: relationships,
            namespaces: namespaces, notes: notes,
            accTitle: accTitle, accDescription: accDescr,
            diagramTitle: diagramTitle
        )
    }

    /// Reconstructs `PositionedErDiagram` for the typed-descriptor factory.
    var erDiagramStruct: PositionedErDiagram? {
        guard case let .erDiagram(
            entities, relationships, accTitle, accDescr, diagramTitle, config
        ) = content else { return nil }
        return PositionedErDiagram(
            width: width, height: height,
            entities: entities, relationships: relationships,
            accTitle: accTitle, accDescr: accDescr,
            diagramTitle: diagramTitle, config: config
        )
    }
}

// MARK: - SVGRenderRegistry

/// Canonical SVG rendering dispatcher. Routes `PositionedGraph.diagram.type`
/// to a per-family descriptor. All 28 supported diagram families have an
/// entry in `all`; the lookup is therefore total under normal use, and
/// the `notYetImplemented` throw is reserved for future cases.
enum SVGRenderRegistry {

    static let all: [DiagramType: SVGRenderDescriptor] = [
        .sequenceDiagram: .typed(.sequenceDiagram, { $0.sequenceDiagramStruct }) { diagram, _, colors, font, transparent in
            try renderSequenceSvg(diagram, colors, font, transparent)
        },
        .classDiagram: .typed(.classDiagram, { $0.classDiagramStruct }) { diagram, _, colors, font, transparent in
            try renderClassSvg(diagram, colors, font, transparent)
        },
        .erDiagram: .typed(.erDiagram, { $0.erDiagramStruct }) { diagram, _, colors, font, transparent in
            try renderErSvg(diagram, colors, font, transparent)
        },
        .xyChart: .typed(.xyChart, { $0.xyChart }) { chart, _, colors, font, transparent in
            renderXYChartSvg(chart, colors, font, transparent, interactive: false)
        },
        .pie: .typed(.pie, { $0.pieChart }) { chart, _, colors, font, transparent in
            renderPieSvg(chart, colors, font, transparent)
        },
        .journey: .typed(.journey, { $0.journeyDiagram }) { diagram, diagramId, colors, font, transparent in
            try renderJourneySvg(diagram, colors, font, transparent, diagramId: diagramId ?? "mermaid-0")
        },
        .gantt: .typed(.gantt, { $0.ganttDiagram }) { data, diagramId, colors, font, transparent in
            try renderGanttSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
        },
        .quadrantChart: .typed(.quadrantChart, { $0.quadrantChart }) { chart, _, colors, font, transparent in
            renderQuadrantSvg(chart, colors, font, transparent)
        },
        .requirement: .typed(.requirement, { $0.requirementDiagram }) { data, diagramId, colors, font, transparent in
            try renderRequirementSvg(data, colors, font, transparent,
                diagramId: diagramId,
                look: data.config.look,
                theme: data.config.theme,
                htmlLabels: data.config.htmlLabels)
        },
        .flowchart: SVGRenderDescriptor(
            type: .flowchart,
            renderPositioned: { positioned, _, colors, font, transparent in
                try renderSvg(positioned, colors, font, transparent)
            }
        ),
        .stateDiagram: SVGRenderDescriptor(
            type: .stateDiagram,
            renderPositioned: { positioned, _, colors, font, transparent in
                try renderSvg(positioned, colors, font, transparent)
            }
        ),
        .gitGraph: .typed(.gitGraph, { $0.gitGraphDiagram }) { data, diagramId, _, _, _ in
            renderGitGraphSvg(data, diagramId: diagramId ?? "")
        },
        .mindmap: .typed(.mindmap, { $0.mindmapDiagram }) { data, diagramId, colors, font, transparent in
            renderMindmapSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
        },
        .timeline: .typed(.timeline, { $0.timelineDiagram }) { data, diagramId, colors, font, transparent in
            try renderTimelineSvg(data, diagramId: diagramId ?? "mermaid-0", colors, font, transparent)
        },
        .sankey: .typed(.sankey, { $0.sankeyDiagram }) { diagram, diagramId, colors, font, transparent in
            renderSankeySvg(diagram, colors, font, transparent, diagramId: diagramId)
        },
        .block: .typed(.block, { $0.blockDiagram }) { data, diagramId, colors, font, transparent in
            try renderBlockSvg(data, diagramId: diagramId ?? "", colors: colors, fontFamily: font, transparent: transparent)
        },
        .packet: .typed(.packet, { $0.packetDiagram }) { data, _, colors, font, transparent in
            renderPacketSvg(data, colors, font, transparent, theme: data.theme)
        },
        .kanban: .typed(.kanban, { $0.kanbanDiagram }) { data, diagramId, colors, font, transparent in
            try renderKanbanSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
        },
        .architecture: .typed(.architecture, { $0.architectureDiagram }) { data, diagramId, colors, font, transparent in
            try renderArchitectureSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
        },
        .radar: .typed(.radar, { $0.radarDiagram }) { diagram, _, colors, font, transparent in
            renderRadarSvg(diagram, colors: colors, font: font, transparent: transparent)
        },
        .treemap: .typed(.treemap, { $0.treemapDiagram }) { data, diagramId, colors, font, transparent in
            renderTreemapSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
        },
        .venn: .typed(.venn, { $0.vennDiagram }) { data, diagramId, colors, font, transparent in
            renderVennSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
        },
        .ishikawa: .typed(.ishikawa, { $0.ishikawaDiagram }) { data, diagramId, colors, font, transparent in
            renderIshikawaSvg(data, diagramId: diagramId ?? "", colors: colors, fontFamily: font, transparent: transparent)
        },
        .treeView: .typed(.treeView, { $0.treeViewDiagram }) { data, diagramId, _, font, _ in
            renderTreeViewSvg(data, diagramId: diagramId ?? "", font: font)
        },
        .eventModeling: .typed(.eventModeling, { $0.eventModelingDiagram }) { data, diagramId, colors, font, transparent in
            renderEventModelingSvg(data, diagramId: diagramId ?? "", colors: colors, font: font, transparent: transparent)
        },
        .wardleyBeta: .typed(.wardleyBeta, { $0.wardleyMapDiagram }) { diagram, _, colors, font, transparent in
            renderWardleyMapSvg(diagram, colors: colors, font: font, transparent: transparent)
        },
        .c4: .typed(.c4, { $0.c4Diagram }) { diagram, diagramId, colors, font, transparent in
            try renderC4Svg(diagram, diagramId: diagramId ?? "", colors, font, transparent)
        },
        .zenuml: .typed(.zenuml, { $0.zenumlDiagram }) { data, _, colors, font, transparent in
            renderZenUMLSvg(data, colors: colors, font: font, transparent: transparent)
        },
    ]

    /// Render a pre-parsed / pre-laid-out `PositionedGraph` to SVG.
    static func render(
        positioned: PositionedGraph,
        diagramId: String? = nil,
        colors: DiagramColors,
        font: String,
        transparent: Bool
    ) throws -> String {
        let type = positioned.diagram.type
        guard let descriptor = all[type] else {
            throw DiagramError.notYetImplemented(
                "SVG rendering for \(type.rawValue)"
            )
        }
        return try descriptor.renderPositioned(positioned, diagramId, colors, font, transparent)
    }
}
