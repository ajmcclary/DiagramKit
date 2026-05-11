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
        .sequenceDiagram: SVGRenderDescriptor(type: .sequenceDiagram) { _, lines, fm, options, _, colors, font, transparent in
            try _renderSequenceSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
        },
        .classDiagram: SVGRenderDescriptor(type: .classDiagram) { _, lines, fm, options, _, colors, font, transparent in
            try _renderClassSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
        },
        .erDiagram: SVGRenderDescriptor(type: .erDiagram) { _, lines, fm, options, _, colors, font, transparent in
            try _renderErSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
        },
        .xyChart: SVGRenderDescriptor(
            type: .xyChart,
            render: { _, lines, fm, options, _, colors, font, transparent in
                try _renderXYChartSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, colors, font, transparent in
                guard case let .xyChart(chart) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.xyChart)
                }
                return renderXYChartSvg(chart, colors, font, transparent, interactive: false)
            }
        ),
        .pie: SVGRenderDescriptor(type: .pie) { _, lines, fm, _, _, colors, font, transparent in
            try _renderPieSvgCase(lines: lines, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .journey: SVGRenderDescriptor(type: .journey) { _, lines, fm, options, _, colors, font, transparent in
            try _renderJourneySvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
        },
        .gantt: SVGRenderDescriptor(type: .gantt) { source, _, fm, _, _, colors, font, transparent in
            try _renderGanttSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .quadrantChart: SVGRenderDescriptor(
            type: .quadrantChart,
            render: { _, lines, fm, _, _, colors, font, transparent in
                try _renderQuadrantSvgCase(lines: lines, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, colors, font, transparent in
                guard case let .quadrantChart(chart) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.quadrantChart)
                }
                return renderQuadrantSvg(chart, colors, font, transparent)
            }
        ),
        .requirement: SVGRenderDescriptor(type: .requirement) { _, lines, fm, options, _, colors, font, transparent in
            try _renderRequirementSvgCase(lines: lines, fm: fm, options: options, colors: colors, font: font, transparent: transparent)
        },
        .flowchart: SVGRenderDescriptor(type: .flowchart) { source, _, fm, options, layoutConfig, colors, font, transparent in
            try _renderFlowchartSvgCase(source: source, fm: fm, options: options, layoutConfig: layoutConfig, colors: colors, font: font, transparent: transparent)
        },
        .stateDiagram: SVGRenderDescriptor(type: .stateDiagram) { source, _, fm, options, layoutConfig, colors, font, transparent in
            // State diagrams route through the flowchart SVG renderer.
            try _renderFlowchartSvgCase(source: source, fm: fm, options: options, layoutConfig: layoutConfig, colors: colors, font: font, transparent: transparent)
        },
        .gitGraph: SVGRenderDescriptor(type: .gitGraph) { source, _, fm, _, _, _, _, _ in
            try _renderGitGraphSvgCase(source: source, fm: fm)
        },
        .mindmap: SVGRenderDescriptor(type: .mindmap) { source, _, fm, _, _, colors, font, transparent in
            try _renderMindmapSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .timeline: SVGRenderDescriptor(type: .timeline) { source, _, fm, _, _, colors, font, transparent in
            try _renderTimelineSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .sankey: SVGRenderDescriptor(
            type: .sankey,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderSankeySvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, colors, font, transparent in
                guard case let .sankey(diagram) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.sankey)
                }
                return renderSankeySvg(diagram, colors, font, transparent)
            }
        ),
        .block: SVGRenderDescriptor(type: .block) { source, _, fm, _, _, colors, font, transparent in
            try _renderBlockSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .packet: SVGRenderDescriptor(type: .packet) { source, _, fm, _, _, colors, font, transparent in
            try _renderPacketSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .kanban: SVGRenderDescriptor(type: .kanban) { source, _, fm, _, _, colors, font, transparent in
            try _renderKanbanSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .architecture: SVGRenderDescriptor(type: .architecture) { source, _, fm, _, _, colors, font, transparent in
            try _renderArchitectureSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .radar: SVGRenderDescriptor(
            type: .radar,
            render: { source, _, fm, _, _, colors, font, transparent in
                try _renderRadarSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
            },
            renderPositioned: { positioned, colors, font, transparent in
                guard case let .radar(diagram) = positioned.content else {
                    throw MermaidStructuralError.payloadMismatch(.radar)
                }
                return renderRadarSvg(diagram, colors: colors, font: font, transparent: transparent)
            }
        ),
        .treemap: SVGRenderDescriptor(type: .treemap) { source, _, fm, _, _, colors, font, transparent in
            try _renderTreemapSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .venn: SVGRenderDescriptor(type: .venn) { source, _, fm, _, _, colors, font, transparent in
            try _renderVennSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .ishikawa: SVGRenderDescriptor(type: .ishikawa) { source, _, fm, _, _, colors, font, transparent in
            try _renderIshikawaSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .treeView: SVGRenderDescriptor(type: .treeView) { source, _, fm, _, _, colors, font, transparent in
            try _renderTreeViewSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .eventModeling: SVGRenderDescriptor(type: .eventModeling) { source, _, fm, _, _, colors, font, transparent in
            try _renderEventModelingSvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .wardleyBeta: SVGRenderDescriptor(type: .wardleyBeta) { source, _, fm, _, _, colors, font, transparent in
            try _renderWardleySvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
        .c4: SVGRenderDescriptor(type: .c4) { source, _, fm, _, _, colors, font, transparent in
            try _renderC4SvgCase(source: source, fm: fm, colors: colors, font: font, transparent: transparent)
        },
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
        return try rp(positioned, colors, font, transparent)
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
