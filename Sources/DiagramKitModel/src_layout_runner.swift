// Extracted from src_layout.swift (audit A2 split). Orchestrates the
// ELK invocation pipeline: chooses between SEPARATE / INCLUDE_CHILDREN /
// flat graph shapes based on subgraph state, runs the layout engine on a
// worker thread, falls back to a flat layout on nested-layout failure,
// and threads `_LayoutDiagnostics` through both paths.
import Foundation
import DiagramKitCommon

func _layoutGraphSyncWithConfig(
    _ graph: DiagramDocument,
    _ config: LayoutConfig
) throws -> PositionedGraph {
    let parsed: _ParsedGraph
    switch graph.payload {
    case .flowchart(let graph), .stateDiagram(let graph):
        parsed = graph
    default:
        return PositionedGraph(diagram: graph)
    }

    let diagnostics = _LayoutDiagnostics()
    var elkGraph: ElkGraphNode
    if !parsed.subgraphs.isEmpty {
        let hasDirectionOverride = parsed.subgraphs.contains(where: { $0.direction != nil })
        elkGraph = hasDirectionOverride
            ? _buildElkGraph(parsed, diagnostics: diagnostics)
            : _buildElkGraphNoCrossEdges(parsed, diagnostics: diagnostics)
    } else {
        elkGraph = _buildElkGraph(parsed, diagnostics: diagnostics)
    }

    // Override ELK spacing options with LayoutConfig values
    _applyLayoutConfig(config, to: &elkGraph)

    do {
        let rawLaidOut = try layoutEngineSync(elkGraph.toDictionary())
        let laidOut = ElkGraphNode(from: rawLaidOut)
        var positioned = _extractPositionedGraph(parsed, laidOut, diagramType: graph.type, diagnostics: diagnostics)
        positioned.diagnostics = diagnostics.items
        return positioned
    } catch {
        diagnostics.warn("ELK nested layout failed; falling back to flat layout (subgraph nesting collapsed): \(error.localizedDescription)")
        var flatGraph = _buildFlatElkGraph(parsed, diagnostics: diagnostics)
        _applyLayoutConfig(config, to: &flatGraph)
        let rawLaidOut = try layoutEngineSync(flatGraph.toDictionary())
        let laidOut = ElkGraphNode(from: rawLaidOut)
        var positioned = _extractPositionedGraph(parsed, laidOut, diagramType: graph.type, diagnostics: diagnostics)
        positioned.diagnostics = diagnostics.items
        return positioned
    }
}

/// Patch ELK layout options on a built graph with LayoutConfig values.
private func _applyLayoutConfig(_ config: LayoutConfig, to elkGraph: inout ElkGraphNode) {
    let p = Int(config.padding)
    elkGraph.layoutOptions["elk.spacing.nodeNode"] = "\(Int(config.nodeSpacing))"
    elkGraph.layoutOptions["elk.layered.spacing.nodeNodeBetweenLayers"] = "\(Int(config.layerSpacing))"
    elkGraph.layoutOptions["elk.padding"] = "[top=\(p),left=\(p),bottom=\(p),right=\(p)]"
    elkGraph.layoutOptions["elk.spacing.componentComponent"] = "\(Int(config.componentSpacing))"
}

func _layoutGraphSyncFromLayoutEngine(
    _ graph: DiagramDocument,
    _ options: RenderOptions
) throws -> PositionedGraph {
    _ = options
    let parsed: _ParsedGraph
    switch graph.payload {
    case .flowchart(let graph), .stateDiagram(let graph):
        parsed = graph
    default:
        return PositionedGraph(diagram: graph)
    }
    let diagnostics = _LayoutDiagnostics()
    // Matching TS: use SEPARATE when any subgraph has a direction override,
    // INCLUDE_CHILDREN otherwise (simpler cross-hierarchy edge routing).
    if !parsed.subgraphs.isEmpty {
        let hasDirectionOverride = parsed.subgraphs.contains(where: { $0.direction != nil })
        let elkGraph: ElkGraphNode
        if hasDirectionOverride {
            // SEPARATE mode: port-based edge splitting for proper direction handling
            elkGraph = _buildElkGraph(parsed, diagnostics: diagnostics)
        } else {
            // INCLUDE_CHILDREN mode: ELK handles cross-hierarchy edges natively
            elkGraph = _buildElkGraphNoCrossEdges(parsed, diagnostics: diagnostics)
        }
        do {
            let rawLaidOut = try layoutEngineSync(elkGraph.toDictionary())
            let laidOut = ElkGraphNode(from: rawLaidOut)
            var positioned = _extractPositionedGraph(parsed, laidOut, diagramType: graph.type, diagnostics: diagnostics)
            positioned.diagnostics = diagnostics.items
            return positioned
        } catch {
            // Fallback: fully flat layout (subgraph nesting collapsed).
            diagnostics.warn("ELK nested layout failed; falling back to flat layout (subgraph nesting collapsed): \(error.localizedDescription)")
            let flatGraph = _buildFlatElkGraph(parsed, diagnostics: diagnostics)
            let rawLaidOut = try layoutEngineSync(flatGraph.toDictionary())
            let laidOut = ElkGraphNode(from: rawLaidOut)
            var positioned = _extractPositionedGraph(parsed, laidOut, diagramType: graph.type, diagnostics: diagnostics)
            positioned.diagnostics = diagnostics.items
            return positioned
        }
    }
    // No subgraphs — use the standard flat graph builder
    let elkGraph = _buildElkGraph(parsed, diagnostics: diagnostics)
    let rawLaidOut = try layoutEngineSync(elkGraph.toDictionary())
    let laidOut = ElkGraphNode(from: rawLaidOut)
    var positioned = _extractPositionedGraph(parsed, laidOut, diagramType: graph.type, diagnostics: diagnostics)
    positioned.diagnostics = diagnostics.items
    return positioned
}

func _layoutGraphWithDiagnosticsSyncFromLayoutEngine(
    _ graph: DiagramDocument,
    _ options: RenderOptions
) throws -> PositionedGraph {
    try _layoutGraphSyncFromLayoutEngine(graph, options)
}

private func _convertToElkFormat(
    _ graph: DiagramDocument,
    _ options: RenderOptions
) throws {
    _ = graph
    _ = options
    // Intentionally a no-op adapter until full layout-engine parity lands.
}
