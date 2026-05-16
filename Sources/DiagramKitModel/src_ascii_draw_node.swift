// Ported from original/src/ascii/draw.ts — node + multi-section box rendering.
// Extracted from `src_ascii_draw.swift` (audit A6).
import Foundation

// ============================================================================
// Node drawing — renders a node using shape-aware rendering
// ============================================================================

public func drawNode(_ node: AsciiNode, _ graph: AsciiGraph) -> Canvas {
    drawBoxWithGridDimensions(node, graph)
}

private func drawBoxWithGridDimensions(_ node: AsciiNode, _ graph: AsciiGraph) -> Canvas {
    guard let gc = node.gridCoord else {
        return mkCanvas(0, 0)
    }
    let useAscii = graph.config.useAscii

    // Width spans 2 columns (border + content)
    var w = 0
    for i in 0..<2 {
        w += graph.columnWidth[gc.x + i] ?? 0
    }
    // Height spans 2 rows (border + content)
    var h = 0
    for i in 0..<2 {
        h += graph.rowHeight[gc.y + i] ?? 0
    }

    var box = mkCanvas(max(0, w), max(0, h))

    // Get corner characters for this shape type
    let corners = getCorners(node.shape, useAscii)

    // State-end uses double border
    let isDoubleBox = node.shape == "state-end"
    let hChar: Character = useAscii ? (isDoubleBox ? "=" : "-") : (isDoubleBox ? "═" : "─")
    let vChar: Character = useAscii ? (isDoubleBox ? "‖" : "|") : (isDoubleBox ? "║" : "│")

    let doubleCorners = useAscii
        ? CornerChars(tl: "#", tr: "#", bl: "#", br: "#")
        : CornerChars(tl: "╔", tr: "╗", bl: "╚", br: "╝")
    let effectiveCorners = isDoubleBox ? doubleCorners : corners

    // Draw box border
    for x in 1..<w { box[x][0] = hChar }
    for x in 1..<w { box[x][h] = hChar }
    for y in 1..<h { box[0][y] = vChar }
    for y in 1..<h { box[w][y] = vChar }
    box[0][0] = effectiveCorners.tl
    box[w][0] = effectiveCorners.tr
    box[0][h] = effectiveCorners.bl
    box[w][h] = effectiveCorners.br

    // Center the multi-line display label inside the box
    let lines = splitLines(node.displayLabel)
    let textCenterY = Int(floor(Double(h) / 2.0))
    let startY = textCenterY - Int(floor(Double(lines.count - 1) / 2.0))

    for i in 0..<lines.count {
        let line = lines[i]
        let textX = Int(floor(Double(w) / 2.0)) - Int(ceil(Double(line.count) / 2.0)) + 1
        for (j, ch) in line.enumerated() {
            let px = textX + j
            let py = startY + i
            if px >= 0, px < box.count, py >= 0, py < (box[0].count) {
                box[px][py] = ch
            }
        }
    }

    return box
}

public func drawBox(_ node: AsciiNode, _ graph: AsciiGraph) -> Canvas {
    drawNode(node, graph)
}

// ============================================================================
// Multi-section box drawing — for class and ER diagram nodes
// ============================================================================

public func drawMultiBox(_ sections: [[String]], _ useAscii: Bool, _ padding: Int = 1) -> Canvas {
    let maxTextWidth = sections.flatMap { $0 }.map { $0.count }.max() ?? 0
    let innerWidth = maxTextWidth + (2 * max(0, padding))
    let boxWidth = innerWidth + 2

    var totalLines = 0
    for section in sections {
        totalLines += max(1, section.count)
    }
    let dividerCount = max(0, sections.count - 1)
    let boxHeight = totalLines + dividerCount + 2

    let h: Character = useAscii ? "-" : "─"
    let v: Character = useAscii ? "|" : "│"
    let tl: Character = useAscii ? "+" : "┌"
    let tr: Character = useAscii ? "+" : "┐"
    let bl: Character = useAscii ? "+" : "└"
    let br: Character = useAscii ? "+" : "┘"
    let dl: Character = useAscii ? "+" : "├"
    let dr: Character = useAscii ? "+" : "┤"

    var canvas = mkCanvas(max(0, boxWidth - 1), max(0, boxHeight - 1))

    canvas[0][0] = tl
    canvas[boxWidth - 1][0] = tr
    canvas[0][boxHeight - 1] = bl
    canvas[boxWidth - 1][boxHeight - 1] = br

    for x in 1 ..< boxWidth - 1 {
        canvas[x][0] = h
        canvas[x][boxHeight - 1] = h
    }

    for y in 1 ..< boxHeight - 1 {
        canvas[0][y] = v
        canvas[boxWidth - 1][y] = v
    }

    var row = 1
    for s in 0 ..< sections.count {
        let section = sections[s].isEmpty ? [""] : sections[s]
        for line in section {
            let startX = 1 + max(0, padding)
            for (i, ch) in line.enumerated() where (startX + i) < (boxWidth - 1) {
                canvas[startX + i][row] = ch
            }
            row += 1
        }

        if s < sections.count - 1 {
            canvas[0][row] = dl
            canvas[boxWidth - 1][row] = dr
            for x in 1 ..< boxWidth - 1 {
                canvas[x][row] = h
            }
            row += 1
        }
    }

    return canvas
}
