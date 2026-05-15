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

// MARK: - SVGRenderRegistry

/// Canonical SVG rendering dispatcher. Routes `PositionedGraph.diagram.type`
/// to a per-family descriptor. All 28 supported diagram families have an
/// entry in `all`; the lookup is therefore total under normal use, and
/// the `notYetImplemented` throw is reserved for future cases.
enum SVGRenderRegistry {

    static let all: [DiagramType: SVGRenderDescriptor] = [
        .sequenceDiagram: SVGRenderDescriptor(
            type: .sequenceDiagram,
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .sequenceDiagram(actors, messages, blocks, lifelines, activations, notes, boxes, bottomActors, rectHighlights, title, accTitle, accDescr) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.sequenceDiagram)
                }
                let diagram = PositionedSequenceDiagram(
                    width: positioned.width, height: positioned.height,
                    actors: actors, lifelines: lifelines, messages: messages,
                    activations: activations, blocks: blocks, notes: notes,
                    boxes: boxes, bottomActors: bottomActors,
                    rectHighlights: rectHighlights, title: title,
                    accTitle: accTitle, accDescr: accDescr
                )
                return try renderSequenceSvg(diagram, colors, font, transparent)
            }
        ),
        .classDiagram: SVGRenderDescriptor(
            type: .classDiagram,
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .classDiagram(classes, relationships, namespaces, notes, accTitle, accDescr, diagramTitle) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.classDiagram)
                }
                let diagram = PositionedClassDiagram(
                    width: positioned.width, height: positioned.height,
                    classes: classes, relationships: relationships,
                    namespaces: namespaces, notes: notes,
                    accTitle: accTitle, accDescription: accDescr,
                    diagramTitle: diagramTitle
                )
                return try renderClassSvg(diagram, colors, font, transparent)
            }
        ),
        .erDiagram: SVGRenderDescriptor(
            type: .erDiagram,
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .erDiagram(entities, relationships, accTitle, accDescr, diagramTitle, config) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.erDiagram)
                }
                let diagram = PositionedErDiagram(
                    width: positioned.width, height: positioned.height,
                    entities: entities, relationships: relationships,
                    accTitle: accTitle, accDescr: accDescr,
                    diagramTitle: diagramTitle,
                    config: config
                )
                return try renderErSvg(diagram, colors, font, transparent)
            }
        ),
        .xyChart: SVGRenderDescriptor(
            type: .xyChart,
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .xyChart(chart) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.xyChart)
                }
                return renderXYChartSvg(chart, colors, font, transparent, interactive: false)
            }
        ),
        .pie: SVGRenderDescriptor(
            type: .pie,
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .pie(chart) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.pie)
                }
                return renderPieSvg(chart, colors, font, transparent)
            }
        ),
        .journey: SVGRenderDescriptor(
            type: .journey,
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .journey(diagram) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.journey)
                }
                return try renderJourneySvg(diagram, colors, font, transparent, diagramId: diagramId ?? "mermaid-0")
            }
        ),
        .gantt: SVGRenderDescriptor(
            type: .gantt,
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .gantt(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.gantt)
                }
                return try renderGanttSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
            }
        ),
        .quadrantChart: SVGRenderDescriptor(
            type: .quadrantChart,
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .quadrantChart(chart) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.quadrantChart)
                }
                return renderQuadrantSvg(chart, colors, font, transparent)
            }
        ),
        .requirement: SVGRenderDescriptor(
            type: .requirement,
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .requirement(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.requirement)
                }
                return try renderRequirementSvg(data, colors, font, transparent,
                    diagramId: diagramId,
                    look: data.config.look,
                    theme: data.config.theme,
                    htmlLabels: data.config.htmlLabels)
            }
        ),
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
        .gitGraph: SVGRenderDescriptor(
            type: .gitGraph,
            renderPositioned: { positioned, diagramId, _, _, _ in
                guard case let .gitGraph(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.gitGraph)
                }
                return renderGitGraphSvg(data, diagramId: diagramId ?? "")
            }
        ),
        .mindmap: SVGRenderDescriptor(
            type: .mindmap,
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .mindmap(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.mindmap)
                }
                return renderMindmapSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
            }
        ),
        .timeline: SVGRenderDescriptor(
            type: .timeline,
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .timeline(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.timeline)
                }
                return try renderTimelineSvg(data, diagramId: diagramId ?? "mermaid-0", colors, font, transparent)
            }
        ),
        .sankey: SVGRenderDescriptor(
            type: .sankey,
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .sankey(diagram) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.sankey)
                }
                return renderSankeySvg(diagram, colors, font, transparent, diagramId: diagramId)
            }
        ),
        .block: SVGRenderDescriptor(
            type: .block,
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .block(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.block)
                }
                return try renderBlockSvg(data, diagramId: diagramId ?? "", colors: colors, fontFamily: font, transparent: transparent)
            }
        ),
        .packet: SVGRenderDescriptor(
            type: .packet,
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .packet(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.packet)
                }
                return renderPacketSvg(data, colors, font, transparent, theme: data.theme)
            }
        ),
        .kanban: SVGRenderDescriptor(
            type: .kanban,
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .kanban(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.kanban)
                }
                return try renderKanbanSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
            }
        ),
        .architecture: SVGRenderDescriptor(
            type: .architecture,
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .architecture(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.architecture)
                }
                return try renderArchitectureSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
            }
        ),
        .radar: SVGRenderDescriptor(
            type: .radar,
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .radar(diagram) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.radar)
                }
                return renderRadarSvg(diagram, colors: colors, font: font, transparent: transparent)
            }
        ),
        .treemap: SVGRenderDescriptor(
            type: .treemap,
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .treemap(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.treemap)
                }
                return renderTreemapSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
            }
        ),
        .venn: SVGRenderDescriptor(
            type: .venn,
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .venn(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.venn)
                }
                return renderVennSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
            }
        ),
        .ishikawa: SVGRenderDescriptor(
            type: .ishikawa,
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .ishikawa(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.ishikawa)
                }
                return renderIshikawaSvg(data, diagramId: diagramId ?? "", colors: colors, fontFamily: font, transparent: transparent)
            }
        ),
        .treeView: SVGRenderDescriptor(
            type: .treeView,
            renderPositioned: { positioned, diagramId, _, font, _ in
                guard case let .treeView(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.treeView)
                }
                return renderTreeViewSvg(data, diagramId: diagramId ?? "", font: font)
            }
        ),
        .eventModeling: SVGRenderDescriptor(
            type: .eventModeling,
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .eventModeling(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.eventModeling)
                }
                return renderEventModelingSvg(data, diagramId: diagramId ?? "", colors: colors, font: font, transparent: transparent)
            }
        ),
        .wardleyBeta: SVGRenderDescriptor(
            type: .wardleyBeta,
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .wardleyBeta(diagram) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.wardleyBeta)
                }
                return renderWardleyMapSvg(diagram, colors: colors, font: font, transparent: transparent)
            }
        ),
        .c4: SVGRenderDescriptor(
            type: .c4,
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .c4(diagram) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.c4)
                }
                return try renderC4Svg(diagram, diagramId: diagramId ?? "", colors, font, transparent)
            }
        ),
        .zenuml: SVGRenderDescriptor(
            type: .zenuml,
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .zenuml(data) = positioned.content else {
                    throw DiagramStructuralError.payloadMismatch(.zenuml)
                }
                return renderZenUMLSvg(data, colors: colors, font: font, transparent: transparent)
            }
        ),
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
