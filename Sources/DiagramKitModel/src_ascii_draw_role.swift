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

/// Border characters the class/ER/sequence ASCII renderers draw as box
/// chrome; every other non-space character inside a box is label text.
/// (`fillRolesForNodeBox`'s `_borderChars` below is deliberately larger —
/// node boxes also use corners, dividers, and marker glyphs.)
let asciiBoxBorderChars: Set<Character> = [
    "┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "│", "─",
    "╭", "╮", "╰", "╯", "+", "-", "|",
]

func classifyAsciiBoxChar(_ ch: Character) -> CharRole {
    asciiBoxBorderChars.contains(ch) ? .border : .text
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
