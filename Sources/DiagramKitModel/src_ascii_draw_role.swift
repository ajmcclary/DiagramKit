// Ported from original/src/ascii/draw.ts — role-canvas overlay helpers and the
// border-character set used to distinguish box borders from text labels in the
// role grid. Extracted from `src_ascii_draw.swift` (audit A6). Top-level
// functions move from `private` to default `internal` because the orchestrator
// (`drawGraph`) calls them from `src_ascii_draw.swift`.
import Foundation

// ============================================================================
// Role tracking helpers
// ============================================================================

func fillRolesFromCanvas(
    _ roleCanvas: inout RoleCanvas,
    _ canvas: Canvas,
    _ offset: DrawingCoord,
    _ role: CharRole
) {
    for x in 0..<canvas.count {
        for y in 0..<(canvas[0].count) {
            let ch = canvas[x][y]
            if ch != " " {
                let rx = x + offset.x
                let ry = y + offset.y
                if rx >= 0, ry >= 0 {
                    setRole(&roleCanvas, rx, ry, role)
                }
            }
        }
    }
}

func fillRolesFromCanvases(
    _ roleCanvas: inout RoleCanvas,
    _ canvases: [Canvas],
    _ offset: DrawingCoord,
    _ role: CharRole
) {
    for canvas in canvases {
        fillRolesFromCanvas(&roleCanvas, canvas, offset, role)
    }
}

private let _borderChars: Set<Character> = [
    "┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "│", "─",
    "╭", "╮", "╰", "╯", "+", "-", "|", "'", ":", ".",
    "╟", "╢", "╔", "╗", "╚", "╝", "═", "║",
    "◯", "◎", "◇", "⌜", "⌝", "⌞", "⌟", "(", ")", "●", "◉",
    "▷", "/", "\\",
]

func fillRolesForNodeBox(
    _ roleCanvas: inout RoleCanvas,
    _ canvas: Canvas,
    _ offset: DrawingCoord
) {
    for x in 0..<canvas.count {
        for y in 0..<(canvas[0].count) {
            let ch = canvas[x][y]
            if ch != " " {
                let rx = x + offset.x
                let ry = y + offset.y
                if rx >= 0, ry >= 0 {
                    setRole(&roleCanvas, rx, ry, _borderChars.contains(ch) ? .border : .text)
                }
            }
        }
    }
}
