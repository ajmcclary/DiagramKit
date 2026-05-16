// Ported from original/src/ascii/draw.ts — single-edge arrow rendering pipeline.
// Extracted from `src_ascii_draw.swift` (audit A6).
import Foundation

// ============================================================================
// Arrow drawing — path, corners, arrowheads, box-start junctions, labels
// ============================================================================

private func reverseDirection(_ dir: Direction) -> Direction {
    if dirEquals(dir, Up) { return Down }
    if dirEquals(dir, Down) { return Up }
    if dirEquals(dir, Left) { return Right }
    if dirEquals(dir, Right) { return Left }
    if dirEquals(dir, UpperLeft) { return LowerRight }
    if dirEquals(dir, UpperRight) { return LowerLeft }
    if dirEquals(dir, LowerLeft) { return UpperRight }
    if dirEquals(dir, LowerRight) { return UpperLeft }
    return Middle
}

private func drawPath(
    _ graph: AsciiGraph,
    _ path: [GridCoord],
    _ style: AsciiEdgeStyle = .solid
) -> (Canvas, [[DrawingCoord]], [Direction]) {
    var canvas = copyCanvas(graph.canvas)
    var previousCoord = path[0]
    var linesDrawn: [[DrawingCoord]] = []
    var lineDirs: [Direction] = []

    for i in 1..<path.count {
        let nextCoord = path[i]
        let prevDC = _gridToDrawingCoord(graph, previousCoord)
        let nextDC = _gridToDrawingCoord(graph, nextCoord)

        if prevDC == nextDC {
            previousCoord = nextCoord
            continue
        }

        let dir = determineDirection(from: previousCoord, to: nextCoord)
        var segment = drawLine(&canvas, prevDC, nextDC, 1, -1, graph.config.useAscii, style)
        if segment.isEmpty { segment.append(prevDC) }
        linesDrawn.append(segment)
        lineDirs.append(dir)
        previousCoord = nextCoord
    }

    return (canvas, linesDrawn, lineDirs)
}

private func drawBoxStart(
    _ graph: AsciiGraph,
    _ path: [GridCoord],
    _ firstLine: [DrawingCoord],
    _ sourceShape: String
) -> Canvas {
    var canvas = copyCanvas(graph.canvas)
    if graph.config.useAscii { return canvas }

    // Skip for state pseudo-states
    if sourceShape == "state-start" || sourceShape == "state-end" {
        return canvas
    }

    guard !firstLine.isEmpty, path.count >= 2 else { return canvas }
    let from = firstLine[0]
    let dir = determineDirection(from: path[0], to: path[1])

    func safeSet(_ x: Int, _ y: Int, _ ch: Character) {
        if x >= 0, x < canvas.count, y >= 0, y < (canvas.first?.count ?? 0) {
            canvas[x][y] = ch
        }
    }

    if dirEquals(dir, Up) { safeSet(from.x, from.y + 1, "┴") }
    else if dirEquals(dir, Down) { safeSet(from.x, from.y - 1, "┬") }
    else if dirEquals(dir, Left) { safeSet(from.x + 1, from.y, "┤") }
    else if dirEquals(dir, Right) { safeSet(from.x - 1, from.y, "├") }

    return canvas
}

private func drawArrowHead(
    _ graph: AsciiGraph,
    _ lastLine: [DrawingCoord],
    _ fallbackDir: Direction
) -> Canvas {
    var canvas = copyCanvas(graph.canvas)
    guard !lastLine.isEmpty else { return canvas }

    let from = lastLine[0]
    let lastPos = lastLine[lastLine.count - 1]
    var dir = _determineDrawingDirection(from: from, to: lastPos)
    if lastLine.count == 1 || dirEquals(dir, Middle) { dir = fallbackDir }

    let ch: Character

    if !graph.config.useAscii {
        if dirEquals(dir, Up) { ch = "▲" }
        else if dirEquals(dir, Down) { ch = "▼" }
        else if dirEquals(dir, Left) { ch = "◄" }
        else if dirEquals(dir, Right) { ch = "►" }
        else if dirEquals(dir, UpperRight) { ch = "◥" }
        else if dirEquals(dir, UpperLeft) { ch = "◤" }
        else if dirEquals(dir, LowerRight) { ch = "◢" }
        else if dirEquals(dir, LowerLeft) { ch = "◣" }
        else {
            if dirEquals(fallbackDir, Up) { ch = "▲" }
            else if dirEquals(fallbackDir, Down) { ch = "▼" }
            else if dirEquals(fallbackDir, Left) { ch = "◄" }
            else if dirEquals(fallbackDir, Right) { ch = "►" }
            else if dirEquals(fallbackDir, UpperRight) { ch = "◥" }
            else if dirEquals(fallbackDir, UpperLeft) { ch = "◤" }
            else if dirEquals(fallbackDir, LowerRight) { ch = "◢" }
            else if dirEquals(fallbackDir, LowerLeft) { ch = "◣" }
            else { ch = "●" }
        }
    } else {
        if dirEquals(dir, Up) { ch = "^" }
        else if dirEquals(dir, Down) { ch = "v" }
        else if dirEquals(dir, Left) { ch = "<" }
        else if dirEquals(dir, Right) { ch = ">" }
        else {
            if dirEquals(fallbackDir, Up) { ch = "^" }
            else if dirEquals(fallbackDir, Down) { ch = "v" }
            else if dirEquals(fallbackDir, Left) { ch = "<" }
            else if dirEquals(fallbackDir, Right) { ch = ">" }
            else { ch = "*" }
        }
    }

    if lastPos.x >= 0, lastPos.x < canvas.count, lastPos.y >= 0, lastPos.y < (canvas.first?.count ?? 0) {
        canvas[lastPos.x][lastPos.y] = ch
    }
    return canvas
}

private func drawCorners(_ graph: AsciiGraph, _ path: [GridCoord]) -> Canvas {
    var canvas = copyCanvas(graph.canvas)

    for idx in 1..<(path.count - 1) {
        let coord = path[idx]
        let dc = _gridToDrawingCoord(graph, coord)
        let prevDir = determineDirection(from: path[idx - 1], to: coord)
        let nextDir = determineDirection(from: coord, to: path[idx + 1])

        let corner: Character
        if !graph.config.useAscii {
            if (dirEquals(prevDir, Right) && dirEquals(nextDir, Down)) ||
                (dirEquals(prevDir, Up) && dirEquals(nextDir, Left)) {
                corner = "┐"
            } else if (dirEquals(prevDir, Right) && dirEquals(nextDir, Up)) ||
                        (dirEquals(prevDir, Down) && dirEquals(nextDir, Left)) {
                corner = "┘"
            } else if (dirEquals(prevDir, Left) && dirEquals(nextDir, Down)) ||
                        (dirEquals(prevDir, Up) && dirEquals(nextDir, Right)) {
                corner = "┌"
            } else if (dirEquals(prevDir, Left) && dirEquals(nextDir, Up)) ||
                        (dirEquals(prevDir, Down) && dirEquals(nextDir, Right)) {
                corner = "└"
            } else {
                corner = "+"
            }
        } else {
            corner = "+"
        }

        if dc.x >= 0, dc.x < canvas.count, dc.y >= 0, dc.y < (canvas.first?.count ?? 0) {
            canvas[dc.x][dc.y] = corner
        }
    }

    return canvas
}

private func drawTextOnLine(_ canvas: inout Canvas, _ line: [DrawingCoord], _ label: String, _ isUpwardEdge: Bool?) {
    guard line.count >= 2 else { return }
    let minX = min(line[0].x, line[1].x)
    let maxX = max(line[0].x, line[1].x)
    let minY = min(line[0].y, line[1].y)
    let maxY = max(line[0].y, line[1].y)
    let middleX = minX + Int(floor(Double(maxX - minX) / 2.0))
    var middleY = minY + Int(floor(Double(maxY - minY) / 2.0))

    // Offset label vertically on bidirectional edges
    if let isUpward = isUpwardEdge, minX == maxX {
        let segmentHeight = maxY - minY
        let offset = max(1, Int(floor(Double(segmentHeight) / 4.0)))
        middleY += isUpward ? offset : -offset
    }

    let lines = splitLines(label)
    let startY = middleY - Int(floor(Double(lines.count - 1) / 2.0))

    for (i, lineText) in lines.enumerated() {
        let startX = middleX - Int(floor(Double(lineText.count) / 2.0))
        drawText(&canvas, start: DrawingCoord(x: startX, y: startY + i), text: lineText)
    }
}

private func drawArrowLabel(_ graph: AsciiGraph, _ edge: AsciiEdge) -> Canvas {
    var canvas = copyCanvas(graph.canvas)
    if edge.text.isEmpty { return canvas }

    let drawingLine = _lineToDrawing(graph, edge.labelLine)

    var isUpwardEdge: Bool?
    if edge.path.count >= 2 {
        let startY = edge.path[0].y
        let endY = edge.path[edge.path.count - 1].y
        if endY < startY { isUpwardEdge = true }
        else if endY > startY { isUpwardEdge = false }
    }

    drawTextOnLine(&canvas, drawingLine, edge.text, isUpwardEdge)
    return canvas
}

public func drawArrow(_ graph: AsciiGraph, _ edge: AsciiEdge) -> (Canvas, Canvas, Canvas, Canvas, Canvas, Canvas) {
    if edge.path.isEmpty {
        let empty = copyCanvas(graph.canvas)
        return (empty, empty, empty, empty, empty, empty)
    }

    let labelCanvas = drawArrowLabel(graph, edge)
    let (pathCanvas, linesDrawn, lineDirs) = drawPath(graph, edge.path, edge.style)

    let boxStartCanvas: Canvas
    if !linesDrawn.isEmpty {
        boxStartCanvas = drawBoxStart(graph, edge.path, linesDrawn[0], edge.from.shape)
    } else {
        boxStartCanvas = copyCanvas(graph.canvas)
    }

    // End arrowhead
    let arrowHeadEndCanvas: Canvas
    if edge.hasArrowEnd, !linesDrawn.isEmpty, !lineDirs.isEmpty {
        arrowHeadEndCanvas = drawArrowHead(
            graph,
            linesDrawn[linesDrawn.count - 1],
            lineDirs[lineDirs.count - 1]
        )
    } else {
        arrowHeadEndCanvas = copyCanvas(graph.canvas)
    }

    // Start arrowhead (bidirectional)
    let arrowHeadStartCanvas: Canvas
    if edge.hasArrowStart, !linesDrawn.isEmpty, !lineDirs.isEmpty {
        let firstLine = linesDrawn[0]
        let firstPoint = firstLine[0]
        let startDir = reverseDirection(lineDirs[0])

        var arrowPos = DrawingCoord(x: firstPoint.x, y: firstPoint.y)
        if dirEquals(lineDirs[0], Right) { arrowPos.x = firstPoint.x - 1 }
        else if dirEquals(lineDirs[0], Left) { arrowPos.x = firstPoint.x + 1 }
        else if dirEquals(lineDirs[0], Down) { arrowPos.y = firstPoint.y - 1 }
        else if dirEquals(lineDirs[0], Up) { arrowPos.y = firstPoint.y + 1 }

        let syntheticLine = [firstPoint, arrowPos]
        arrowHeadStartCanvas = drawArrowHead(graph, syntheticLine, startDir)
    } else {
        arrowHeadStartCanvas = copyCanvas(graph.canvas)
    }

    let cornersCanvas = drawCorners(graph, edge.path)

    return (pathCanvas, boxStartCanvas, arrowHeadEndCanvas, arrowHeadStartCanvas, cornersCanvas, labelCanvas)
}
