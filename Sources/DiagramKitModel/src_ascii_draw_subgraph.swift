// Ported from original/src/ascii/draw.ts — subgraph outline + label rendering.
// Extracted from `src_ascii_draw.swift` (audit A6).
import Foundation

// ============================================================================
// Subgraph drawing
// ============================================================================

public func drawSubgraphBox(_ sg: AsciiSubgraph, _ graph: AsciiGraph) -> Canvas {
    let width = sg.maxX - sg.minX
    let height = sg.maxY - sg.minY
    if width <= 0 || height <= 0 { return mkCanvas(0, 0) }

    var canvas = mkCanvas(width, height)

    if !graph.config.useAscii {
        for x in 1..<width { canvas[x][0] = "─" }
        for x in 1..<width { canvas[x][height] = "─" }
        for y in 1..<height { canvas[0][y] = "│" }
        for y in 1..<height { canvas[width][y] = "│" }
        canvas[0][0] = "┌"
        canvas[width][0] = "┐"
        canvas[0][height] = "└"
        canvas[width][height] = "┘"
    } else {
        for x in 1..<width { canvas[x][0] = "-" }
        for x in 1..<width { canvas[x][height] = "-" }
        for y in 1..<height { canvas[0][y] = "|" }
        for y in 1..<height { canvas[width][y] = "|" }
        canvas[0][0] = "+"
        canvas[width][0] = "+"
        canvas[0][height] = "+"
        canvas[width][height] = "+"
    }

    return canvas
}

public func drawSubgraphLabel(_ sg: AsciiSubgraph, _ graph: AsciiGraph) -> (Canvas, DrawingCoord) {
    let width = sg.maxX - sg.minX
    let height = sg.maxY - sg.minY
    if width <= 0 || height <= 0 { return (mkCanvas(0, 0), DrawingCoord(x: 0, y: 0)) }

    var canvas = mkCanvas(width, height)

    let lines = splitLines(sg.name)
    for (i, line) in lines.enumerated() {
        let labelY = 1 + i
        var labelX = Int(floor(Double(width) / 2.0)) - Int(floor(Double(line.count) / 2.0))
        if labelX < 1 { labelX = 1 }

        for (j, ch) in line.enumerated() {
            if labelX + j < width, labelY < height {
                canvas[labelX + j][labelY] = ch
            }
        }
    }

    return (canvas, DrawingCoord(x: sg.minX, y: sg.minY))
}
