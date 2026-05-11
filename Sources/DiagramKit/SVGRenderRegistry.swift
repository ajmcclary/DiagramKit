import Foundation
import DiagramKitModel
import DiagramKitCommon

// MARK: - SVGRenderDescriptor

/// Per-diagram-type SVG rendering descriptor. The closure receives the
/// preprocessed source plus parsed frontmatter and returns the SVG string.
///
/// Some per-family closures still take raw source today (they parse +
/// layout internally); others consume already-positioned data. The
/// shape is kept uniform so the registry can route by `DiagramType`
/// without case-by-case dispatch in the caller.
struct SVGRenderDescriptor: Sendable {
    let type: DiagramType
    let render: @Sendable (
        _ decodedSource: String,
        _ lines: [String],
        _ frontmatter: DiagramFrontmatter?,
        _ options: RenderOptions,
        _ layoutConfig: LayoutConfig,
        _ colors: DiagramColors,
        _ font: String,
        _ transparent: Bool
    ) throws -> String

    /// Positioned-graph entry point. When non-nil, the renderer consumes a
    /// pre-parsed / pre-laid-out `PositionedGraph` rather than parsing and
    /// laying out the source itself. Descriptors that still do inline
    /// parse+layout return `nil` here.
    var renderPositioned: (@Sendable (
        _ positioned: PositionedGraph,
        _ diagramId: String?,
        _ colors: DiagramColors,
        _ font: String,
        _ transparent: Bool
    ) throws -> String)? = nil
}

// MARK: - SVGRenderRegistry

/// Canonical SVG rendering dispatcher. Routes from the preprocessed source
/// through `DiagramRegistry.detect` (the same detector parser/layout use)
/// to a per-`DiagramType` descriptor. Replaces the legacy
/// `_DiagramRoutingType` enum and `detectDiagramType` chain that lived
/// inside `src_index.swift` — there is now exactly one source of truth
/// for header detection, anchored on `DiagramRegistry`.
enum SVGRenderRegistry {

    static let all: [DiagramType: SVGRenderDescriptor] = [
        .sequenceDiagram: SVGRenderDescriptor(
            type: .sequenceDiagram,
            render: { _, lines, fm, options, _, colors, font, transparent in
                try _renderSequenceSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .sequenceDiagram(actors, messages, blocks, lifelines, activations, notes, boxes, bottomActors, rectHighlights, title, accTitle, accDescr) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.sequenceDiagram)
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
            render: { _, lines, fm, options, _, colors, font, transparent in
                try _renderClassSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .classDiagram(classes, relationships, namespaces, notes, accTitle, accDescr, diagramTitle) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.classDiagram)
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
            render: { _, lines, fm, options, _, colors, font, transparent in
                try _renderErSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .erDiagram(entities, relationships, accTitle, accDescr, diagramTitle) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.erDiagram)
                }
                let diagram = PositionedErDiagram(
                    width: positioned.width, height: positioned.height,
                    entities: entities, relationships: relationships,
                    accTitle: accTitle, accDescr: accDescr,
                    diagramTitle: diagramTitle
                )
                return try renderErSvg(diagram, colors, font, transparent)
            }
        ),
        .xyChart: SVGRenderDescriptor(
            type: .xyChart,
            render: { _, lines, fm, options, _, colors, font, transparent in
                try _renderXYChartSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .xyChart(chart) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.xyChart)
                }
                return renderXYChartSvg(chart, colors, font, transparent, interactive: false)
            }
        ),
        .pie: SVGRenderDescriptor(
            type: .pie,
            render: { _, lines, fm, _, _, colors, font, transparent in
                try _renderPieSvgCase(lines: lines, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .pie(chart) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.pie)
                }
                return renderPieSvg(chart, colors, font, transparent)
            }
        ),
        .journey: SVGRenderDescriptor(
            type: .journey,
            render: { _, lines, fm, options, _, colors, font, transparent in
                try _renderJourneySvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .journey(diagram) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.journey)
                }
                return try renderJourneySvg(diagram, colors, font, transparent)
            }
        ),
        .gantt: SVGRenderDescriptor(
            type: .gantt,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderGanttSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .gantt(data) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.gantt)
                }
                return try renderGanttSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
            }
        ),
        .quadrantChart: SVGRenderDescriptor(
            type: .quadrantChart,
            render: { _, lines, fm, _, _, colors, font, transparent in
                try _renderQuadrantSvgCase(lines: lines, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .quadrantChart(chart) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.quadrantChart)
                }
                return renderQuadrantSvg(chart, colors, font, transparent)
            }
        ),
        .requirement: SVGRenderDescriptor(type: .requirement) { _, lines, fm, options, _, colors, font, transparent in
            try _renderRequirementSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
        },
        .flowchart: SVGRenderDescriptor(
            type: .flowchart,
            render: { source, _, fm, options, layoutConfig, colors, font, transparent in
                try _renderFlowchartSvgCase(source: source, fm: fm, options: options, layoutConfig: layoutConfig, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, _, colors, font, transparent in
                try renderSvg(positioned, colors, font, transparent)
            }
        ),
        .stateDiagram: SVGRenderDescriptor(
            type: .stateDiagram,
            render: { source, _, fm, options, layoutConfig, colors, font, transparent in
                try _renderFlowchartSvgCase(source: source, fm: fm, options: options, layoutConfig: layoutConfig, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, _, colors, font, transparent in
                try renderSvg(positioned, colors, font, transparent)
            }
        ),
        .gitGraph: SVGRenderDescriptor(
            type: .gitGraph,
            render: { source, _, fm, _, _, _, _, _ in
                try _renderGitGraphSvgCase(source: source, fm: fm)
            },
            renderPositioned: { positioned, diagramId, _, _, _ in
                guard case let .gitGraph(data) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.gitGraph)
                }
                return renderGitGraphSvg(data, diagramId: diagramId ?? "")
            }
        ),
        .mindmap: SVGRenderDescriptor(
            type: .mindmap,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderMindmapSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .mindmap(data) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.mindmap)
                }
                return renderMindmapSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
            }
        ),
        .timeline: SVGRenderDescriptor(
            type: .timeline,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderTimelineSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .timeline(data) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.timeline)
                }
                return try renderTimelineSvg(data, diagramId: diagramId ?? "mermaid-0", colors, font, transparent)
            }
        ),
        .sankey: SVGRenderDescriptor(
            type: .sankey,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderSankeySvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .sankey(diagram) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.sankey)
                }
                return renderSankeySvg(diagram, colors, font, transparent, diagramId: diagramId)
            }
        ),
        .block: SVGRenderDescriptor(
            type: .block,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderBlockSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .block(data) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.block)
                }
                return try renderBlockSvg(data, diagramId: diagramId ?? "", colors: colors, fontFamily: font, transparent: transparent)
            }
        ),
        .packet: SVGRenderDescriptor(type: .packet) { source, _, fm, _, _, colors, font, transparent in
            try _renderPacketSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .kanban: SVGRenderDescriptor(
            type: .kanban,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderKanbanSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .kanban(data) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.kanban)
                }
                return try renderKanbanSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
            }
        ),
        .architecture: SVGRenderDescriptor(
            type: .architecture,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderArchitectureSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .architecture(data) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.architecture)
                }
                return try renderArchitectureSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
            }
        ),
        .radar: SVGRenderDescriptor(
            type: .radar,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderRadarSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .radar(diagram) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.radar)
                }
                return renderRadarSvg(diagram, colors: colors, font: font, transparent: transparent)
            }
        ),
        .treemap: SVGRenderDescriptor(
            type: .treemap,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderTreemapSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .treemap(data) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.treemap)
                }
                return renderTreemapSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
            }
        ),
        .venn: SVGRenderDescriptor(
            type: .venn,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderVennSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .venn(data) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.venn)
                }
                return renderVennSvg(data, diagramId: diagramId ?? "", colors, font, transparent)
            }
        ),
        .ishikawa: SVGRenderDescriptor(
            type: .ishikawa,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderIshikawaSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .ishikawa(data) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.ishikawa)
                }
                return renderIshikawaSvg(data, diagramId: diagramId ?? "", colors: colors, fontFamily: font, transparent: transparent)
            }
        ),
        .treeView: SVGRenderDescriptor(
            type: .treeView,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderTreeViewSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, diagramId, _, font, _ in
                guard case let .treeView(data) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.treeView)
                }
                return renderTreeViewSvg(data, diagramId: diagramId ?? "", font: font)
            }
        ),
        .eventModeling: SVGRenderDescriptor(
            type: .eventModeling,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderEventModelingSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .eventModeling(data) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.eventModeling)
                }
                return renderEventModelingSvg(data, diagramId: diagramId ?? "", colors: colors, font: font, transparent: transparent)
            }
        ),
        .wardleyBeta: SVGRenderDescriptor(
            type: .wardleyBeta,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderWardleySvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, _, colors, font, transparent in
                guard case let .wardleyBeta(diagram) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.wardleyBeta)
                }
                return renderWardleyMapSvg(diagram, colors: colors, font: font, transparent: transparent)
            }
        ),
        .c4: SVGRenderDescriptor(
            type: .c4,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderC4SvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, diagramId, colors, font, transparent in
                guard case let .c4(diagram) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.c4)
                }
                return try renderC4Svg(diagram, diagramId: diagramId ?? "", colors, font, transparent)
            }
        ),
        .zenuml: SVGRenderDescriptor(type: .zenuml) { source, _, fm, _, _, colors, font, transparent in
            try _renderZenUMLSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
    ]

    /// Render a pre-parsed / pre-laid-out `PositionedGraph` to SVG.
    ///
    /// Only diagram families whose descriptors have a `renderPositioned`
    /// closure are supported through this path. Other families must go
    /// through the source-based `render(_:frontmatter:...)` entry point.
    static func render(
        positioned: PositionedGraph,
        diagramId: String? = nil,
        colors: DiagramColors,
        font: String,
        transparent: Bool
    ) throws -> String {
        let type = positioned.diagram.type
        guard let svgDescriptor = all[type] else {
            throw BeautifulMermaidError.notYetImplemented(
                "SVG rendering for \(type.rawValue)"
            )
        }
        guard let rp = svgDescriptor.renderPositioned else {
            throw BeautifulMermaidError.notYetImplemented(
                "Positioned-graph SVG rendering for \(type.rawValue)"
            )
        }
        return try rp(positioned, diagramId, colors, font, transparent)
    }

    /// Render the preprocessed source through the appropriate per-family
    /// descriptor. Detection is done via `DiagramRegistry.detect` so it
    /// stays in lockstep with parser/layout dispatch.
    static func render(
        _ decodedSource: String,
        frontmatter: DiagramFrontmatter?,
        options: RenderOptions,
        layoutConfig: LayoutConfig,
        colors: DiagramColors,
        font: String,
        transparent: Bool
    ) throws -> String {
        let descriptor = DiagramRegistry.detect(from: decodedSource)
        let lines = MermaidSourceNormalizer.statements(decodedSource)
        guard let svgDescriptor = all[descriptor.type] else {
            throw BeautifulMermaidError.notYetImplemented(
                "SVG rendering for \(descriptor.type.rawValue)"
            )
        }
        return try svgDescriptor.render(
            decodedSource, lines, frontmatter, options, layoutConfig, colors, font, transparent
        )
    }
}
