// Ported from original/src/ascii/draw.ts — fan-in/fan-out bundled edge
// rendering and multi-way junction character logic. Extracted from
// `src_ascii_draw.swift` (audit A6). Top-level functions move from `private`
// to default `internal` because the orchestrator (`drawGraph`) calls them
// from `src_ascii_draw.swift`.
import Foundation

// ============================================================================
// Node attachment point helper
// ============================================================================

private func getNodeAttachmentPoint(
    _ graph: AsciiGraph,
    _ node: AsciiNode,
    _ dir: Direction
) -> DrawingCoord {
    guard let gc = node.gridCoord, let baseCoord = node.drawingCoord else {
        return DrawingCoord(x: 0, y: 0)
    }

    var w = 0
    for i in 0..<2 { w += graph.columnWidth[gc.x + i] ?? 0 }
    var h = 0
    for i in 0..<2 { h += graph.rowHeight[gc.y + i] ?? 0 }

    let gridDimensions = ShapeDimensions(
        width: w + 1,
        height: h + 1,
        labelArea: ShapeLabelArea(x: 0, y: 0, width: 0, height: 0),
        gridColumns: [0, 0, 0],
        gridRows: [0, 0, 0]
    )

    return getShapeAttachmentPoint(node.shape, dir, gridDimensions, baseCoord)
}

// ============================================================================
// Bundled edge drawing
// ============================================================================

func drawBundledEdgeSegment(
    _ graph: AsciiGraph,
    _ edge: AsciiEdge,
    _ bundle: EdgeBundle
) -> (Canvas, Canvas, Canvas, Canvas, Canvas, Canvas) {
    let empty = copyCanvas(graph.canvas)

    guard let pathToJunction = edge.pathToJunction, !pathToJunction.isEmpty else {
        return (empty, empty, empty, empty, empty, empty)
    }

    var pathCanvas = copyCanvas(graph.canvas)
    let useAscii = graph.config.useAscii

    let drawingPath: [DrawingCoord] = pathToJunction.enumerated().map { idx, gc in
        if bundle.type == "fan-in" && idx == 0 {
            return getNodeAttachmentPoint(graph, edge.from, edge.startDir)
        }
        if bundle.type == "fan-out" && idx == pathToJunction.count - 1 {
            return getNodeAttachmentPoint(graph, edge.to, edge.endDir)
        }
        return _gridToDrawingCoord(graph, gc)
    }

    for i in 1..<drawingPath.count {
        let from = drawingPath[i - 1]
        let to = drawingPath[i]
        if from != to {
            _ = drawLine(&pathCanvas, from, to, 1, -1, useAscii, edge.style)
        }
    }

    // Corners at path bends
    var cornersCanvas = copyCanvas(graph.canvas)
    for idx in 1..<(pathToJunction.count - 1) {
        let coord = pathToJunction[idx]
        let dc = _gridToDrawingCoord(graph, coord)
        let prevDir = determineDirection(from: pathToJunction[idx - 1], to: coord)
        let nextDir = determineDirection(from: coord, to: pathToJunction[idx + 1])

        let corner: Character
        if !useAscii {
            if (dirEquals(prevDir, Right) && dirEquals(nextDir, Down)) ||
                (dirEquals(prevDir, Up) && dirEquals(nextDir, Left)) { corner = "┐" }
            else if (dirEquals(prevDir, Right) && dirEquals(nextDir, Up)) ||
                      (dirEquals(prevDir, Down) && dirEquals(nextDir, Left)) { corner = "┘" }
            else if (dirEquals(prevDir, Left) && dirEquals(nextDir, Down)) ||
                      (dirEquals(prevDir, Up) && dirEquals(nextDir, Right)) { corner = "┌" }
            else if (dirEquals(prevDir, Left) && dirEquals(nextDir, Up)) ||
                      (dirEquals(prevDir, Down) && dirEquals(nextDir, Right)) { corner = "└" }
            else { corner = "+" }
        } else { corner = "+" }

        if dc.x >= 0, dc.x < cornersCanvas.count, dc.y >= 0, dc.y < (cornersCanvas.first?.count ?? 0) {
            cornersCanvas[dc.x][dc.y] = corner
        }
    }

    // Box start connector (fan-in, from source node)
    var boxStartCanvas = copyCanvas(graph.canvas)
    if bundle.type == "fan-in", pathToJunction.count >= 2 {
        let firstPoint = drawingPath[0]
        let dir = determineDirection(from: pathToJunction[0], to: pathToJunction[1])
        if !useAscii {
            func safeSet(_ x: Int, _ y: Int, _ ch: Character) {
                if x >= 0, x < boxStartCanvas.count, y >= 0, y < (boxStartCanvas.first?.count ?? 0) {
                    boxStartCanvas[x][y] = ch
                }
            }
            if dirEquals(dir, Up) { safeSet(firstPoint.x, firstPoint.y, "┴") }
            else if dirEquals(dir, Down) { safeSet(firstPoint.x, firstPoint.y, "┬") }
            else if dirEquals(dir, Left) { safeSet(firstPoint.x, firstPoint.y, "┤") }
            else if dirEquals(dir, Right) { safeSet(firstPoint.x, firstPoint.y, "├") }
        }
    }

    let labelCanvas = copyCanvas(graph.canvas)
    return (pathCanvas, boxStartCanvas, empty, empty, cornersCanvas, labelCanvas)
}

func drawBundleSharedPath(_ graph: AsciiGraph, _ bundle: EdgeBundle) -> (Canvas, Canvas) {
    var pathCanvas = copyCanvas(graph.canvas)
    var cornersCanvas = copyCanvas(graph.canvas)

    guard bundle.sharedPath.count >= 2 else {
        return (pathCanvas, cornersCanvas)
    }

    let useAscii = graph.config.useAscii
    let style = bundle.edges.first?.style ?? .solid
    let graphDir = graph.config.graphDirection

    let drawingPath: [DrawingCoord] = bundle.sharedPath.enumerated().map { idx, gc in
        if bundle.type == "fan-in" && idx == bundle.sharedPath.count - 1 {
            let entryDir = graphDir == "TD" ? Up : Left
            return getNodeAttachmentPoint(graph, bundle.sharedNode, entryDir)
        }
        if bundle.type == "fan-out" && idx == 0 {
            let exitDir = graphDir == "TD" ? Down : Right
            return getNodeAttachmentPoint(graph, bundle.sharedNode, exitDir)
        }
        return _gridToDrawingCoord(graph, gc)
    }

    for i in 1..<drawingPath.count {
        let from = drawingPath[i - 1]
        let to = drawingPath[i]
        if from != to {
            _ = drawLine(&pathCanvas, from, to, 1, -1, useAscii, style)
        }
    }

    for idx in 1..<(bundle.sharedPath.count - 1) {
        let coord = bundle.sharedPath[idx]
        let dc = _gridToDrawingCoord(graph, coord)
        let prevDir = determineDirection(from: bundle.sharedPath[idx - 1], to: coord)
        let nextDir = determineDirection(from: coord, to: bundle.sharedPath[idx + 1])

        let corner: Character
        if !useAscii {
            if (dirEquals(prevDir, Right) && dirEquals(nextDir, Down)) ||
                (dirEquals(prevDir, Up) && dirEquals(nextDir, Left)) { corner = "┐" }
            else if (dirEquals(prevDir, Right) && dirEquals(nextDir, Up)) ||
                      (dirEquals(prevDir, Down) && dirEquals(nextDir, Left)) { corner = "┘" }
            else if (dirEquals(prevDir, Left) && dirEquals(nextDir, Down)) ||
                      (dirEquals(prevDir, Up) && dirEquals(nextDir, Right)) { corner = "┌" }
            else if (dirEquals(prevDir, Left) && dirEquals(nextDir, Up)) ||
                      (dirEquals(prevDir, Down) && dirEquals(nextDir, Right)) { corner = "└" }
            else { corner = "+" }
        } else { corner = "+" }

        if dc.x >= 0, dc.x < cornersCanvas.count, dc.y >= 0, dc.y < (cornersCanvas.first?.count ?? 0) {
            cornersCanvas[dc.x][dc.y] = corner
        }
    }

    return (pathCanvas, cornersCanvas)
}

func drawBundleArrowhead(_ graph: AsciiGraph, _ bundle: EdgeBundle) -> Canvas {
    var canvas = copyCanvas(graph.canvas)
    guard bundle.sharedPath.count >= 2 else { return canvas }

    let lastIdx = bundle.sharedPath.count - 1
    let dir = determineDirection(from: bundle.sharedPath[lastIdx - 1], to: bundle.sharedPath[lastIdx])

    let graphDir = graph.config.graphDirection
    let entryDir = graphDir == "TD" ? Up : Left
    var dc = getNodeAttachmentPoint(graph, bundle.sharedNode, entryDir)
    if graphDir == "TD" { dc.y -= 1 } else { dc.x -= 1 }

    let ch: Character
    if !graph.config.useAscii {
        if dirEquals(dir, Up) { ch = "▲" }
        else if dirEquals(dir, Down) { ch = "▼" }
        else if dirEquals(dir, Left) { ch = "◄" }
        else if dirEquals(dir, Right) { ch = "►" }
        else { ch = "▼" }
    } else {
        if dirEquals(dir, Up) { ch = "^" }
        else if dirEquals(dir, Down) { ch = "v" }
        else if dirEquals(dir, Left) { ch = "<" }
        else if dirEquals(dir, Right) { ch = ">" }
        else { ch = "v" }
    }

    if dc.x >= 0, dc.x < canvas.count, dc.y >= 0, dc.y < (canvas.first?.count ?? 0) {
        canvas[dc.x][dc.y] = ch
    }
    return canvas
}

func drawBundledEdgeArrowhead(_ graph: AsciiGraph, _ edge: AsciiEdge) -> Canvas {
    var canvas = copyCanvas(graph.canvas)
    guard let pathToJunction = edge.pathToJunction, pathToJunction.count >= 2 else { return canvas }

    let lastIdx = pathToJunction.count - 1
    let dir = determineDirection(from: pathToJunction[lastIdx - 1], to: pathToJunction[lastIdx])

    let graphDir = graph.config.graphDirection
    let entryDir = graphDir == "TD" ? Up : Left
    var dc = getNodeAttachmentPoint(graph, edge.to, entryDir)
    if graphDir == "TD" { dc.y -= 1 } else { dc.x -= 1 }

    let ch: Character
    if !graph.config.useAscii {
        if dirEquals(dir, Up) { ch = "▲" }
        else if dirEquals(dir, Down) { ch = "▼" }
        else if dirEquals(dir, Left) { ch = "◄" }
        else if dirEquals(dir, Right) { ch = "►" }
        else { ch = "▼" }
    } else {
        if dirEquals(dir, Up) { ch = "^" }
        else if dirEquals(dir, Down) { ch = "v" }
        else if dirEquals(dir, Left) { ch = "<" }
        else if dirEquals(dir, Right) { ch = ">" }
        else { ch = "v" }
    }

    if dc.x >= 0, dc.x < canvas.count, dc.y >= 0, dc.y < (canvas.first?.count ?? 0) {
        canvas[dc.x][dc.y] = ch
    }
    return canvas
}

func drawJunctionCharacter(_ graph: AsciiGraph, _ bundle: EdgeBundle) -> Canvas {
    var canvas = copyCanvas(graph.canvas)
    guard let junctionPoint = bundle.junctionPoint else { return canvas }

    let dc = _gridToDrawingCoord(graph, junctionPoint)
    let useAscii = graph.config.useAscii

    var hasUp = false, hasDown = false, hasLeft = false, hasRight = false

    if bundle.sharedPath.count >= 2 {
        let junctionIdx = bundle.type == "fan-in" ? 0 : bundle.sharedPath.count - 1
        let adjacentIdx = bundle.type == "fan-in" ? 1 : bundle.sharedPath.count - 2
        let sharedDir = determineDirection(from: bundle.sharedPath[junctionIdx], to: bundle.sharedPath[adjacentIdx])
        if dirEquals(sharedDir, Down) { hasDown = true }
        else if dirEquals(sharedDir, Up) { hasUp = true }
        else if dirEquals(sharedDir, Right) { hasRight = true }
        else if dirEquals(sharedDir, Left) { hasLeft = true }
    }

    for edge in bundle.edges {
        guard let pathToJunction = edge.pathToJunction, pathToJunction.count >= 2 else { continue }
        let junctionIdx = bundle.type == "fan-in" ? pathToJunction.count - 1 : 0
        let adjacentIdx = bundle.type == "fan-in" ? pathToJunction.count - 2 : 1
        let arrivalDir = determineDirection(from: pathToJunction[adjacentIdx], to: pathToJunction[junctionIdx])
        if dirEquals(arrivalDir, Down) { hasUp = true }
        else if dirEquals(arrivalDir, Up) { hasDown = true }
        else if dirEquals(arrivalDir, Right) { hasLeft = true }
        else if dirEquals(arrivalDir, Left) { hasRight = true }
    }

    let ch: Character
    if !useAscii {
        if hasUp && hasDown && hasLeft && hasRight { ch = "┼" }
        else if hasDown && hasLeft && hasRight && !hasUp { ch = "┬" }
        else if hasUp && hasLeft && hasRight && !hasDown { ch = "┴" }
        else if hasUp && hasDown && hasRight && !hasLeft { ch = "├" }
        else if hasUp && hasDown && hasLeft && !hasRight { ch = "┤" }
        else if hasLeft && hasRight { ch = "─" }
        else if hasUp && hasDown { ch = "│" }
        else if hasDown && hasRight { ch = "┌" }
        else if hasDown && hasLeft { ch = "┐" }
        else if hasUp && hasRight { ch = "└" }
        else if hasUp && hasLeft { ch = "┘" }
        else { ch = "┼" }
    } else {
        ch = "+"
    }

    if dc.x >= 0, dc.x < canvas.count, dc.y >= 0, dc.y < (canvas.first?.count ?? 0) {
        canvas[dc.x][dc.y] = ch
    }
    return canvas
}
