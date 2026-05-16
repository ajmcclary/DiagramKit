// Ported from original/src/ascii/draw.ts — `drawLine` core primitive.
// Extracted from `src_ascii_draw.swift` (audit A6).
import Foundation

// ============================================================================
// Line drawing — 8-directional lines on the canvas
// ============================================================================

public func drawLine(
    _ canvas: inout Canvas,
    _ from: DrawingCoord,
    _ to: DrawingCoord,
    _ offsetFrom: Int,
    _ offsetTo: Int,
    _ useAscii: Bool,
    _ style: AsciiEdgeStyle = .solid
) -> [DrawingCoord] {
    let dir = _determineDrawingDirection(from: from, to: to)
    var drawn: [DrawingCoord] = []

    let hChar: Character
    let vChar: Character

    switch style {
    case .dotted:
        hChar = useAscii ? "." : "┄"
        vChar = useAscii ? ":" : "┆"
    case .thick:
        hChar = useAscii ? "=" : "━"
        vChar = useAscii ? "‖" : "┃"
    case .solid:
        hChar = useAscii ? "-" : "─"
        vChar = useAscii ? "|" : "│"
    }

    func safeSet(_ x: Int, _ y: Int, _ ch: Character) {
        if x >= 0, x < canvas.count, y >= 0, y < (canvas.first?.count ?? 0) {
            canvas[x][y] = ch
            drawn.append(DrawingCoord(x: x, y: y))
        }
    }

    // Pure vertical: Up
    if dirEquals(dir, Up) {
        var y = from.y - offsetFrom
        while y >= to.y - offsetTo {
            safeSet(from.x, y, vChar)
            y -= 1
        }
    }
    // Pure vertical: Down
    else if dirEquals(dir, Down) {
        var y = from.y + offsetFrom
        while y <= to.y + offsetTo {
            safeSet(from.x, y, vChar)
            y += 1
        }
    }
    // Pure horizontal: Left
    else if dirEquals(dir, Left) {
        var x = from.x - offsetFrom
        while x >= to.x - offsetTo {
            safeSet(x, from.y, hChar)
            x -= 1
        }
    }
    // Pure horizontal: Right
    else if dirEquals(dir, Right) {
        var x = from.x + offsetFrom
        while x <= to.x + offsetTo {
            safeSet(x, from.y, hChar)
            x += 1
        }
    }
    // UpperLeft: horizontal left, then vertical up
    else if dirEquals(dir, UpperLeft) {
        var x = from.x - offsetFrom
        while x >= to.x {
            safeSet(x, from.y, hChar)
            x -= 1
        }
        var y = from.y - 1
        while y >= to.y - offsetTo {
            safeSet(to.x, y, vChar)
            y -= 1
        }
    }
    // UpperRight: horizontal right, then vertical up
    else if dirEquals(dir, UpperRight) {
        var x = from.x + offsetFrom
        while x <= to.x {
            safeSet(x, from.y, hChar)
            x += 1
        }
        var y = from.y - 1
        while y >= to.y - offsetTo {
            safeSet(to.x, y, vChar)
            y -= 1
        }
    }
    // LowerLeft: horizontal left, then vertical down
    else if dirEquals(dir, LowerLeft) {
        var x = from.x - offsetFrom
        while x >= to.x {
            safeSet(x, from.y, hChar)
            x -= 1
        }
        var y = from.y + 1
        while y <= to.y + offsetTo {
            safeSet(to.x, y, vChar)
            y += 1
        }
    }
    // LowerRight: if dx ≤ 1, straight vertical; else horizontal right then vertical down
    else if dirEquals(dir, LowerRight) {
        let dx = to.x - from.x
        if dx <= 1 {
            var y = from.y + offsetFrom
            while y <= to.y + offsetTo {
                safeSet(from.x, y, vChar)
                y += 1
            }
        } else {
            var x = from.x + offsetFrom
            while x <= to.x {
                safeSet(x, from.y, hChar)
                x += 1
            }
            var y = from.y + 1
            while y <= to.y + offsetTo {
                safeSet(to.x, y, vChar)
                y += 1
            }
        }
    }

    return drawn
}
