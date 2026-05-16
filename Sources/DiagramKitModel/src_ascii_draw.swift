// Ported from original/src/ascii/draw.ts — whole-graph ASCII draw orchestrator.
// The per-responsibility helpers (node / line / arrow / bundle / subgraph /
// role / coord) were split into sibling `src_ascii_draw_*.swift` files in
// audit A6 so this file owns only the orchestration step.
import Foundation

// ============================================================================
// Sorting helper
// ============================================================================

private func sortSubgraphsByDepth(_ subgraphs: [AsciiSubgraph]) -> [AsciiSubgraph] {
    func getDepth(_ sg: AsciiSubgraph) -> Int {
        sg.parent == nil ? 0 : 1
    }
    return subgraphs.sorted { getDepth($0) < getDepth($1) }
}

// ============================================================================
// Top-level draw orchestrator
// ============================================================================

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

    // 3. Collect all edge drawing layers
    var lineCanvases: [Canvas] = []
    var cornerCanvases: [Canvas] = []
    var arrowHeadEndCanvases: [Canvas] = []
    var arrowHeadStartCanvases: [Canvas] = []
    var boxStartCanvases: [Canvas] = []
    var labelCanvases: [Canvas] = []
    var junctionCanvases: [Canvas] = []

    var processedBundleTypes = Set<String>()

    for edge in graph.edges {
        if let bundle = edge.bundle, edge.pathToJunction != nil {
            let (pathC, boxStartC, _, _, cornersC, labelC) = drawBundledEdgeSegment(graph, edge, bundle)
            lineCanvases.append(pathC)
            cornerCanvases.append(cornersC)
            boxStartCanvases.append(boxStartC)
            labelCanvases.append(labelC)

            let bundleKey = "\(bundle.type)-\(bundle.sharedNode.name)-\(bundle.sharedNode.index)"
            if !processedBundleTypes.contains(bundleKey) {
                processedBundleTypes.insert(bundleKey)

                let (sharedPathC, sharedCornersC) = drawBundleSharedPath(graph, bundle)
                lineCanvases.append(sharedPathC)
                cornerCanvases.append(sharedCornersC)

                if bundle.type == "fan-in" {
                    arrowHeadEndCanvases.append(drawBundleArrowhead(graph, bundle))
                }

                junctionCanvases.append(drawJunctionCharacter(graph, bundle))
            }

            if bundle.type == "fan-out", edge.hasArrowEnd {
                arrowHeadEndCanvases.append(drawBundledEdgeArrowhead(graph, edge))
            }
        } else {
            let (pathC, boxStartC, arrowHeadEndC, arrowHeadStartC, cornersC, labelC) = drawArrow(graph, edge)
            lineCanvases.append(pathC)
            cornerCanvases.append(cornersC)
            arrowHeadEndCanvases.append(arrowHeadEndC)
            arrowHeadStartCanvases.append(arrowHeadStartC)
            boxStartCanvases.append(boxStartC)
            labelCanvases.append(labelC)
        }
    }

    // 4. Merge edge layers in order
    graph.canvas = mergeCanvasArray(graph.canvas, zero, useAscii, lineCanvases)
    fillRolesFromCanvases(&graph.roleCanvas, lineCanvases, zero, .line)

    graph.canvas = mergeCanvasArray(graph.canvas, zero, useAscii, cornerCanvases)
    fillRolesFromCanvases(&graph.roleCanvas, cornerCanvases, zero, .corner)

    graph.canvas = mergeCanvasArray(graph.canvas, zero, useAscii, junctionCanvases)
    fillRolesFromCanvases(&graph.roleCanvas, junctionCanvases, zero, .junction)

    graph.canvas = mergeCanvasArray(graph.canvas, zero, useAscii, arrowHeadEndCanvases)
    fillRolesFromCanvases(&graph.roleCanvas, arrowHeadEndCanvases, zero, .arrow)

    graph.canvas = mergeCanvasArray(graph.canvas, zero, useAscii, boxStartCanvases)
    fillRolesFromCanvases(&graph.roleCanvas, boxStartCanvases, zero, .junction)

    graph.canvas = mergeCanvasArray(graph.canvas, zero, useAscii, arrowHeadStartCanvases)
    fillRolesFromCanvases(&graph.roleCanvas, arrowHeadStartCanvases, zero, .arrow)

    graph.canvas = mergeCanvasArray(graph.canvas, zero, useAscii, labelCanvases)
    fillRolesFromCanvases(&graph.roleCanvas, labelCanvases, zero, .text)

    // 5. Draw subgraph labels (top layer)
    for sg in graph.subgraphs {
        if sg.nodes.isEmpty { continue }
        let (labelCanvas, offset) = drawSubgraphLabel(sg, graph)
        graph.canvas = mergeCanvases(graph.canvas, offset, useAscii, labelCanvas)
        fillRolesFromCanvas(&graph.roleCanvas, labelCanvas, offset, .text)
    }

    return graph.canvas
}

final class original_src_ascii_draw {
    public init() {}
}
