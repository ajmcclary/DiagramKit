// Ported from original/src/ascii/draw.ts — coordinate helpers shared by line,
// arrow/path, and bundle drawing. Extracted from `src_ascii_draw.swift` so each
// responsibility lives in its own file (audit A6). Visibility moves from
// `private` (file-scope) to default `internal` (module-scope) because these
// helpers are now called across files within `DiagramKitModel`.
import Foundation

// ============================================================================
// Standalone grid→drawing coordinate conversion (for types-based AsciiGraph)
// ============================================================================

func _gridToDrawingCoord(_ graph: AsciiGraph, _ c: GridCoord) -> DrawingCoord {
    var x = 0
    for col in 0..<c.x {
        x += graph.columnWidth[col] ?? 0
    }
    var y = 0
    for row in 0..<c.y {
        y += graph.rowHeight[row] ?? 0
    }
    let colW = graph.columnWidth[c.x] ?? 0
    let rowH = graph.rowHeight[c.y] ?? 0
    return DrawingCoord(
        x: x + (colW / 2) + graph.offsetX,
        y: y + (rowH / 2) + graph.offsetY
    )
}

func _lineToDrawing(_ graph: AsciiGraph, _ line: [GridCoord]) -> [DrawingCoord] {
    line.map { _gridToDrawingCoord(graph, $0) }
}

func _determineDrawingDirection(from: DrawingCoord, to: DrawingCoord) -> Direction {
    determineDirection(from: GridCoord(x: from.x, y: from.y), to: GridCoord(x: to.x, y: to.y))
}
