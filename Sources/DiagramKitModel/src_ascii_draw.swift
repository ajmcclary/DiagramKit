// Ported from original/src/ascii/draw.ts — whole-graph ASCII draw orchestrator.
// The per-responsibility helpers (node / line / arrow / subgraph /
// role / coord) were split into sibling `src_ascii_draw_*.swift` files in
// audit A6 so this file owns only the orchestration step.
import Foundation

// ============================================================================
// Sorting helper
// ============================================================================

private func sortSubgraphsByDepth(_ subgraphs: [AsciiSubgraph]) -> [AsciiSubgraph] {
    // Depth = length of the parent chain (parents are indices into the same
    // flat array). Bounded walk guards against malformed self-referencing
    // parent indices.
    func getDepth(_ sg: AsciiSubgraph) -> Int {
        var depth = 0
        var current = sg.parent
        while let idx = current, idx >= 0, idx < subgraphs.count, depth <= subgraphs.count {
            depth += 1
            current = subgraphs[idx].parent
        }
        return depth
    }
    return subgraphs.enumerated()
        .sorted { a, b in
            let da = getDepth(a.element)
            let db = getDepth(b.element)
            if da != db { return da < db }
            return a.offset < b.offset
        }
        .map(\.element)
}

// ============================================================================
// Top-level draw orchestrator
// ============================================================================

/// Most cell operations the flowchart/state ASCII drawing may take. Every
/// node, subgraph and edge layer is drawn into (and merged from) a canvas
/// the size of the whole diagram, so the work is cells × layers: an
/// 800-node chain, a 50×50 `&` fan-out or 200 nested subgraphs took 50 s to
/// several minutes. Past this the ASCII renderer throws
/// `DiagramInputLimitError(.layoutSize)` instead; SVG and image rendering of
/// the same diagram are unaffected.
public let _asciiFlowchartDrawBudget: Double = 60_000_000

/// Estimated cell operations `drawGraph` will perform on `graph`.
public func _asciiFlowchartDrawWork(_ graph: AsciiGraph) -> Double {
    // The canvas grows while drawing, so size it from the geometry that
    // will be drawn, not from its current extent.
    var (maxX, maxY) = getCanvasSize(graph.canvas)
    for sg in graph.subgraphs {
        maxX = max(maxX, sg.maxX)
        maxY = max(maxY, sg.maxY)
    }
    for node in graph.nodes {
        guard let dc = node.drawingCoord else { continue }
        let (w, h) = node.drawing.map(getCanvasSize) ?? (0, 0)
        maxX = max(maxX, dc.x + w)
        maxY = max(maxY, dc.y + h)
    }
    let cells = Double(maxX + 1) * Double(maxY + 1)
    let layers = Double(graph.nodes.count + graph.subgraphs.count * 2 + graph.edges.count * 6 + 12)
    return cells * layers
}

public func drawGraph(_ graph: inout AsciiGraph) -> Canvas {
    let useAscii = graph.config.useAscii
    let zero = DrawingCoord(x: 0, y: 0)

    // 1. Draw subgraph borders (bottom layer)
    let sortedSgs = sortSubgraphsByDepth(graph.subgraphs)
    for sg in sortedSgs {
        if sg.nodes.isEmpty { continue }
        let sgCanvas = drawSubgraphBox(sg, graph)
        let offset = DrawingCoord(x: sg.minX, y: sg.minY)
        graph.canvas = mergeCanvases(graph.canvas, offset, useAscii, sgCanvas)
        fillRolesFromCanvas(&graph.roleCanvas, sgCanvas, offset, .border)
    }

    // 2. Draw node boxes
    for i in 0..<graph.nodes.count {
        let node = graph.nodes[i]
        if !node.drawn, let dc = node.drawingCoord, let drawing = node.drawing {
            graph.canvas = mergeCanvases(graph.canvas, dc, useAscii, drawing)
            fillRolesForNodeBox(&graph.roleCanvas, drawing, dc)
            graph.nodes[i].drawn = true
        }
    }

    // 3. Collect all edge drawing layers as sparse overlays (only the
    //    non-space cells are retained; the full per-edge canvases are
    //    released as soon as they are extracted).
    var lineOverlays: [SparseCanvasOverlay] = []
    var cornerOverlays: [SparseCanvasOverlay] = []
    var arrowHeadEndOverlays: [SparseCanvasOverlay] = []
    var arrowHeadStartOverlays: [SparseCanvasOverlay] = []
    var boxStartOverlays: [SparseCanvasOverlay] = []
    var labelOverlays: [SparseCanvasOverlay] = []

    for edge in graph.edges {
        let (pathC, boxStartC, arrowHeadEndC, arrowHeadStartC, cornersC, labelC) = drawArrow(graph, edge)
        lineOverlays.append(sparseOverlay(of: pathC))
        cornerOverlays.append(sparseOverlay(of: cornersC))
        arrowHeadEndOverlays.append(sparseOverlay(of: arrowHeadEndC))
        arrowHeadStartOverlays.append(sparseOverlay(of: arrowHeadStartC))
        boxStartOverlays.append(sparseOverlay(of: boxStartC))
        labelOverlays.append(sparseOverlay(of: labelC))
    }

    // 4. Merge edge layers in order
    mergeSparseOverlays(&graph.canvas, zero, useAscii, lineOverlays)
    fillRolesFromSparseOverlays(&graph.roleCanvas, lineOverlays, zero, .line)

    mergeSparseOverlays(&graph.canvas, zero, useAscii, cornerOverlays)
    fillRolesFromSparseOverlays(&graph.roleCanvas, cornerOverlays, zero, .corner)

    mergeSparseOverlays(&graph.canvas, zero, useAscii, arrowHeadEndOverlays)
    fillRolesFromSparseOverlays(&graph.roleCanvas, arrowHeadEndOverlays, zero, .arrow)

    mergeSparseOverlays(&graph.canvas, zero, useAscii, boxStartOverlays)
    fillRolesFromSparseOverlays(&graph.roleCanvas, boxStartOverlays, zero, .junction)

    mergeSparseOverlays(&graph.canvas, zero, useAscii, arrowHeadStartOverlays)
    fillRolesFromSparseOverlays(&graph.roleCanvas, arrowHeadStartOverlays, zero, .arrow)

    mergeSparseOverlays(&graph.canvas, zero, useAscii, labelOverlays)
    fillRolesFromSparseOverlays(&graph.roleCanvas, labelOverlays, zero, .text)

    // 5. Draw subgraph labels (top layer)
    for sg in graph.subgraphs {
        if sg.nodes.isEmpty { continue }
        let (labelCanvas, offset) = drawSubgraphLabel(sg, graph)
        graph.canvas = mergeCanvases(graph.canvas, offset, useAscii, labelCanvas)
        fillRolesFromCanvas(&graph.roleCanvas, labelCanvas, offset, .text)
    }

    return graph.canvas
}

