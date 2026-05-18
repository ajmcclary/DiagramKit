// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import CoreGraphics
import DiagramKitCommon
import DiagramKitModel

/// Canonical CG rendering dispatcher.
///
/// Mirrors `SVGRenderRegistry` and `AsciiDocumentRenderRegistry`:
/// `PositionedGraph.diagram.type` is routed to a per-family closure
/// that invokes the appropriate `DiagramRenderer._drawX(...)` helper.
/// Coverage of all 28 supported diagram families is asserted at file
/// scope (see ``_assertCoversAllFamilies``) so a future family
/// addition fails compile rather than rendering silently.
///
/// Kept internal to `DiagramKitRenderingCG`; no public API change vs.
/// the prior `switch positioned.content { … }` form in
/// `DiagramRenderer.render(_:in:bounds:)`.
enum CGRenderRegistry {

    typealias Render = @Sendable (DiagramRenderer, PositionedGraph, CGContext, CGRect) -> Void

    static let all: [DiagramType: Render] = [
        .classDiagram:    { r, g, c, b in r._drawClass(g, in: c, bounds: b) },
        .erDiagram:       { r, g, c, b in r._drawEr(g, in: c, bounds: b) },
        .sequenceDiagram: { r, g, c, b in r._drawSequence(g, in: c, bounds: b) },
        // Flowchart and stateDiagram share a renderer because state
        // diagrams lower to a flowchart layout before draw.
        .flowchart:       { r, g, c, b in r._drawFlowOrState(g, in: c, bounds: b) },
        .stateDiagram:    { r, g, c, b in r._drawFlowOrState(g, in: c, bounds: b) },
        .xyChart:         { r, g, c, b in r._drawXYChart(g, in: c, bounds: b) },
        .pie:             { r, g, c, b in r._drawPie(g, in: c, bounds: b) },
        .journey:         { r, g, c, b in r._drawJourney(g, in: c, bounds: b) },
        .gantt:           { r, g, c, b in r._drawGantt(g, in: c, bounds: b) },
        .quadrantChart:   { r, g, c, b in r._drawQuadrant(g, in: c, bounds: b) },
        .requirement:     { r, g, c, b in r._drawRequirement(g, in: c, bounds: b) },
        .gitGraph:        { r, g, c, b in r._drawGitGraph(g, in: c, bounds: b) },
        .mindmap:         { r, g, c, b in r._drawMindmap(g, in: c, bounds: b) },
        .timeline:        { r, g, c, b in r._drawTimeline(g, in: c, bounds: b) },
        .sankey:          { r, g, c, b in r._drawSankey(g, in: c, bounds: b) },
        .block:           { r, g, c, b in r._drawBlock(g, in: c, bounds: b) },
        .packet:          { r, g, c, b in r._drawPacket(g, in: c, bounds: b) },
        .kanban:          { r, g, c, b in r._drawKanban(g, in: c, bounds: b) },
        .architecture:    { r, g, c, b in r._drawArchitecture(g, in: c, bounds: b) },
        .radar:           { r, g, c, b in r._drawRadar(g, in: c, bounds: b) },
        .treemap:         { r, g, c, b in r._drawTreemap(g, in: c, bounds: b) },
        .venn:            { r, g, c, b in r._drawVenn(g, in: c, bounds: b) },
        .ishikawa:        { r, g, c, b in r._drawIshikawa(g, in: c, bounds: b) },
        .treeView:        { r, g, c, b in r._drawTreeView(g, in: c, bounds: b) },
        .eventModeling:   { r, g, c, b in r._drawEventModeling(g, in: c, bounds: b) },
        .wardleyBeta:     { r, g, c, b in r._drawWardley(g, in: c, bounds: b) },
        .zenuml:          { r, g, c, b in r._drawZenUML(g, in: c, bounds: b) },
        .c4:              { r, g, c, b in r._drawC4(g, in: c, bounds: b) }
    ]

    /// Dispatch a CG render. No-op for an unrecognized family — the
    /// background is already painted by the caller
    /// (`DiagramRenderer.render`) so an unknown family produces a blank
    /// canvas rather than a crash.
    static func render(
        _ positioned: PositionedGraph,
        renderer: DiagramRenderer,
        in context: CGContext,
        bounds: CGRect
    ) {
        guard let render = all[positioned.diagram.type] else { return }
        render(renderer, positioned, context, bounds)
    }
}

// MARK: - Coverage assertion

/// Compile-time coverage assertion: forces an exhaustive switch over
/// every `DiagramType` so that adding a new case to the enum without
/// updating ``CGRenderRegistry/all`` fails to compile. The function is
/// never called at runtime.
private func _assertCGRenderRegistryCoversAllFamilies() {
    let type: DiagramType = .flowchart
    switch type {
    case .classDiagram, .erDiagram, .sequenceDiagram,
         .flowchart, .stateDiagram, .xyChart, .pie, .journey, .gantt,
         .quadrantChart, .requirement, .gitGraph, .mindmap, .timeline,
         .sankey, .block, .packet, .kanban, .architecture, .radar,
         .treemap, .venn, .ishikawa, .treeView, .eventModeling,
         .wardleyBeta, .zenuml, .c4:
        // Every family has an entry in CGRenderRegistry.all. Adding a
        // new DiagramType case without updating both this switch and
        // the registry table will surface as a "switch must be
        // exhaustive" error here.
        break
    }
}
#endif
