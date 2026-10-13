// Ported from original/src/ascii/canvas.ts
import DiagramKitCommon
import Foundation

// Top-level typealiases moved to DiagramKitModel/AsciiTopLevelAliases.swift

public struct CanvasToStringOptions: Sendable {
    public var roleCanvas: RoleCanvas?
    public var colorMode: ColorMode?
    public var theme: AsciiTheme?

    public init(roleCanvas: RoleCanvas? = nil, colorMode: ColorMode? = nil, theme: AsciiTheme? = nil) {
        self.roleCanvas = roleCanvas
        self.colorMode = colorMode
        self.theme = theme
    }
}

public func mkCanvas(_ x: Int, _ y: Int) -> Canvas {
    let maxX = max(0, x)
    let maxY = max(0, y)
    return (0 ... maxX).map { _ in Array(repeating: Character(" "), count: maxY + 1) }
}

public func copyCanvas(_ source: Canvas) -> Canvas {
    let (maxX, maxY) = getCanvasSize(source)
    return mkCanvas(maxX, maxY)
}

public func mkRoleCanvas(_ x: Int, _ y: Int) -> RoleCanvas {
    let maxX = max(0, x)
    let maxY = max(0, y)
    return (0 ... maxX).map { _ in Array(repeating: nil, count: maxY + 1) }
}

@discardableResult
public func increaseRoleCanvasSize(_ roleCanvas: inout RoleCanvas, _ newX: Int, _ newY: Int) -> RoleCanvas {
    let currX = max(0, roleCanvas.count - 1)
    let currY = max(0, (roleCanvas.first?.count ?? 1) - 1)
    let targetX = max(newX, currX)
    let targetY = max(newY, currY)
    let rowTarget = targetY + 1

    if roleCanvas.isEmpty {
        roleCanvas = mkRoleCanvas(targetX, targetY)
        return roleCanvas
    }
    guard targetX != currX || targetY != currY else { return roleCanvas }

    // Grow in place: pad short columns, then append blank columns.
    // The previous full reallocation ran in O(label × W × H) when callers
    // grew the canvas per character.
    for x in 0 ..< roleCanvas.count where roleCanvas[x].count < rowTarget {
        roleCanvas[x].append(contentsOf: repeatElement(nil, count: rowTarget - roleCanvas[x].count))
    }
    if roleCanvas.count < targetX + 1 {
        let blankColumn = [CharRole?](repeating: nil, count: rowTarget)
        roleCanvas.append(contentsOf: repeatElement(blankColumn, count: targetX + 1 - roleCanvas.count))
    }

    return roleCanvas
}

public func setRole(_ roleCanvas: inout RoleCanvas, _ x: Int, _ y: Int, _ role: CharRole) {
    if x >= roleCanvas.count || y >= (roleCanvas.first?.count ?? 0) {
        _ = increaseRoleCanvasSize(&roleCanvas, x, y)
    }
    if x >= 0, x < roleCanvas.count, y >= 0, y < (roleCanvas.first?.count ?? 0) {
        roleCanvas[x][y] = role
    }
}

/// Place `ch` at `(x, y)` on `canvas`, growing `canvas` and `roleCanvas`
/// to fit if needed, and write the matching `role` into the role canvas.
/// Coordinates `< 0` are ignored.
///
/// Centralises the per-family `func setC(...)` closure that was
/// duplicated across `src_ascii_sequence.swift`,
/// `src_ascii_class_diagram.swift`, and `src_ascii_er_diagram.swift`.
public func setCanvasCharacter(
    _ canvas: inout Canvas,
    _ roleCanvas: inout RoleCanvas,
    _ x: Int,
    _ y: Int,
    _ ch: Character,
    _ role: CharRole
) {
    guard x >= 0, y >= 0 else { return }
    if x >= canvas.count || y >= (canvas.first?.count ?? 0) {
        _ = increaseSize(&canvas, x, y)
        _ = increaseRoleCanvasSize(&roleCanvas, x, y)
    }
    if x < canvas.count, y < (canvas.first?.count ?? 0) {
        canvas[x][y] = ch
        setRole(&roleCanvas, x, y, role)
    }
}

public func getCanvasSize(_ canvas: Canvas) -> (Int, Int) {
    (max(0, canvas.count - 1), max(0, (canvas.first?.count ?? 1) - 1))
}

@discardableResult
public func increaseSize(_ canvas: inout Canvas, _ newX: Int, _ newY: Int) -> Canvas {
    let (currX, currY) = getCanvasSize(canvas)
    let targetX = max(newX, currX)
    let targetY = max(newY, currY)
    let rowTarget = targetY + 1

    if canvas.isEmpty {
        canvas = mkCanvas(targetX, targetY)
        return canvas
    }
    guard targetX != currX || targetY != currY else { return canvas }

    // Grow in place: pad short columns, then append blank columns.
    // The previous full reallocation ran in O(label × W × H) when callers
    // (ER, class) grew the canvas per character / per label line.
    for x in 0 ..< canvas.count where canvas[x].count < rowTarget {
        canvas[x].append(contentsOf: repeatElement(Character(" "), count: rowTarget - canvas[x].count))
    }
    if canvas.count < targetX + 1 {
        let blankColumn = [Character](repeating: Character(" "), count: rowTarget)
        canvas.append(contentsOf: repeatElement(blankColumn, count: targetX + 1 - canvas.count))
    }

    return canvas
}

private let JUNCTION_CHARS: Set<Character> = [
    "─", "│", "┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "╴", "╵", "╶", "╷",
]

public func isJunctionChar(_ c: Character) -> Bool {
    JUNCTION_CHARS.contains(c)
}

private let JUNCTION_MAP: [Character: [Character: Character]] = [
    "─": ["│": "┼", "┌": "┬", "┐": "┬", "└": "┴", "┘": "┴", "├": "┼", "┤": "┼", "┬": "┬", "┴": "┴"],
    "│": ["─": "┼", "┌": "├", "┐": "┤", "└": "├", "┘": "┤", "├": "├", "┤": "┤", "┬": "┼", "┴": "┼"],
    "┌": ["─": "┬", "│": "├", "┐": "┬", "└": "├", "┘": "┼", "├": "├", "┤": "┼", "┬": "┬", "┴": "┼"],
    "┐": ["─": "┬", "│": "┤", "┌": "┬", "└": "┼", "┘": "┤", "├": "┼", "┤": "┤", "┬": "┬", "┴": "┼"],
    "└": ["─": "┴", "│": "├", "┌": "├", "┐": "┼", "┘": "┴", "├": "├", "┤": "┼", "┬": "┼", "┴": "┴"],
    "┘": ["─": "┴", "│": "┤", "┌": "┼", "┐": "┤", "└": "┴", "├": "┼", "┤": "┤", "┬": "┼", "┴": "┴"],
    "├": ["─": "┼", "│": "├", "┌": "├", "┐": "┼", "└": "├", "┘": "┼", "┤": "┼", "┬": "┼", "┴": "┼"],
    "┤": ["─": "┼", "│": "┤", "┌": "┼", "┐": "┤", "└": "┼", "┘": "┤", "├": "┼", "┬": "┼", "┴": "┼"],
    "┬": ["─": "┬", "│": "┼", "┌": "┬", "┐": "┬", "└": "┼", "┘": "┼", "├": "┼", "┤": "┼", "┴": "┼"],
    "┴": ["─": "┴", "│": "┼", "┌": "┼", "┐": "┼", "└": "┴", "┘": "┴", "├": "┼", "┤": "┼", "┬": "┼"],
]

public func mergeJunctions(_ c1: Character, _ c2: Character) -> Character {
    JUNCTION_MAP[c1]?[c2] ?? c1
}

private func isAlphanumeric(_ c: Character) -> Bool {
    c.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
}

// MARK: - Sparse overlays
//
// `drawGraph` accumulates one full-size canvas per edge per drawing layer
// before merging them, which retained 6 × edges × W × H characters until
// the merge step. The merge and role-fill loops only ever read an
// overlay's non-space cells, so the orchestrator stores those cells
// sparsely and folds them with the same rules, in the same order, as
// `mergeCanvases` / `fillRolesFromCanvases`.

public struct SparseOverlayCell: Sendable {
    public let x: Int
    public let y: Int
    public let ch: Character

    public init(x: Int, y: Int, ch: Character) {
        self.x = x
        self.y = y
        self.ch = ch
    }
}

public struct SparseCanvasOverlay: Sendable {
    public let cells: [SparseOverlayCell]
    /// Extents in `getCanvasSize` terms (`count - 1` per axis).
    public let maxX: Int
    public let maxY: Int
}

public func sparseOverlay(of canvas: Canvas) -> SparseCanvasOverlay {
    var cells: [SparseOverlayCell] = []
    for x in 0 ..< canvas.count {
        let column = canvas[x]
        for y in 0 ..< column.count {
            let c = column[y]
            if c != " " {
                cells.append(SparseOverlayCell(x: x, y: y, ch: c))
            }
        }
    }
    return SparseCanvasOverlay(
        cells: cells,
        maxX: max(0, canvas.count - 1),
        maxY: max(0, (canvas.first?.count ?? 1) - 1)
    )
}

public func mergeSparseOverlays(
    _ base: inout Canvas,
    _ offset: DrawingCoord,
    _ useAscii: Bool,
    _ overlays: [SparseCanvasOverlay]
) {
    var (maxX, maxY) = getCanvasSize(base)

    for overlay in overlays {
        maxX = max(maxX, overlay.maxX + offset.x)
        maxY = max(maxY, overlay.maxY + offset.y)
    }

    var merged = mkCanvas(maxX, maxY)

    for x in 0 ... maxX {
        for y in 0 ... maxY {
            if x < base.count, y < (base.first?.count ?? 0) {
                merged[x][y] = base[x][y]
            }
        }
    }

    for overlay in overlays {
        for cell in overlay.cells {
            let mx = cell.x + offset.x
            let my = cell.y + offset.y
            if mx < 0 || mx >= merged.count || my < 0 || my >= (merged.first?.count ?? 0) {
                continue
            }

            let c = cell.ch
            let current = merged[mx][my]
            if !useAscii && isJunctionChar(c) && isJunctionChar(current) {
                merged[mx][my] = mergeJunctions(current, c)
            } else if isAlphanumeric(current) && isAlphanumeric(c) {
                // preserve first-written label text
            } else {
                merged[mx][my] = c
            }
        }
    }

    base = merged
}

public func fillRolesFromSparseOverlays(
    _ roleCanvas: inout RoleCanvas,
    _ overlays: [SparseCanvasOverlay],
    _ offset: DrawingCoord,
    _ role: CharRole
) {
    for overlay in overlays {
        for cell in overlay.cells {
            let rx = cell.x + offset.x
            let ry = cell.y + offset.y
            if rx >= 0, ry >= 0 {
                setRole(&roleCanvas, rx, ry, role)
            }
        }
    }
}

public func mergeCanvases(_ base: Canvas, _ offset: DrawingCoord, _ useAscii: Bool, _ overlays: Canvas...) -> Canvas {
    var (maxX, maxY) = getCanvasSize(base)

    for overlay in overlays {
        let (oX, oY) = getCanvasSize(overlay)
        maxX = max(maxX, oX + offset.x)
        maxY = max(maxY, oY + offset.y)
    }

    var merged = mkCanvas(maxX, maxY)

    for x in 0 ... maxX {
        for y in 0 ... maxY {
            if x < base.count, y < (base.first?.count ?? 0) {
                merged[x][y] = base[x][y]
            }
        }
    }

    for overlay in overlays {
        for x in 0 ..< overlay.count {
            for y in 0 ..< (overlay.first?.count ?? 0) {
                let c = overlay[x][y]
                if c == " " { continue }

                let mx = x + offset.x
                let my = y + offset.y
                if mx < 0 || mx >= merged.count || my < 0 || my >= (merged.first?.count ?? 0) {
                    continue
                }

                let current = merged[mx][my]
                if !useAscii && isJunctionChar(c) && isJunctionChar(current) {
                    merged[mx][my] = mergeJunctions(current, c)
                } else if isAlphanumeric(current) && isAlphanumeric(c) {
                    // preserve first-written label text
                } else {
                    merged[mx][my] = c
                }
            }
        }
    }

    return merged
}

public func canvasToString(_ canvas: Canvas, options: CanvasToStringOptions? = nil) -> String {
    let (maxX, maxY) = getCanvasSize(canvas)

    let roleCanvas = options?.roleCanvas
    let colorMode = options?.colorMode ?? .none
    let theme = options?.theme ?? AsciiTheme(
        fg: "#27272a",
        border: "#a1a1aa",
        line: "#71717a",
        arrow: "#52525b",
        corner: "#71717a",
        junction: "#a1a1aa"
    )

    var lines: [String] = []
    for y in 0 ... maxY {
        if colorMode == .none || roleCanvas == nil {
            // Plain text output — no colors
            var line = ""
            for x in 0 ... maxX {
                line.append(canvas[x][y])
            }
            lines.append(line)
        } else {
            guard let rc = roleCanvas else { continue }
            // Colored output — collect chars and roles for this row
            var chars: [String] = []
            var roles: [CharRole?] = []
            for x in 0 ... maxX {
                chars.append(String(canvas[x][y]))
                if x < rc.count, y < (rc[x].count) {
                    roles.append(rc[x][y])
                } else {
                    roles.append(nil)
                }
            }
            lines.append(colorizeLine(chars, roles, theme, colorMode))
        }
    }
    return lines.joined(separator: "\n")
}

private let VERTICAL_FLIP_MAP: [Character: Character] = [
    "▲": "▼", "▼": "▲",
    "◤": "◣", "◣": "◤",
    "◥": "◢", "◢": "◥",
    "^": "v", "v": "^",
    "┌": "└", "└": "┌",
    "┐": "┘", "┘": "┐",
    "┬": "┴", "┴": "┬",
    "╵": "╷", "╷": "╵",
]

@discardableResult
public func flipCanvasVertically(_ canvas: inout Canvas) -> Canvas {
    for i in canvas.indices {
        canvas[i].reverse()
        for y in canvas[i].indices {
            if let mapped = VERTICAL_FLIP_MAP[canvas[i][y]] {
                canvas[i][y] = mapped
            }
        }
    }
    return canvas
}

@discardableResult
public func flipRoleCanvasVertically(_ roleCanvas: inout RoleCanvas) -> RoleCanvas {
    for i in roleCanvas.indices {
        roleCanvas[i].reverse()
    }
    return roleCanvas
}

// Mirror-image characters for flipCanvasHorizontally. Arrowheads and
// corner glyphs swap to their horizontal counterpart; characters that are
// horizontally symmetric (│ ─ ┬ ┴ ┼ ═ etc.) map to themselves and are
// simply absent from the table.
private let HORIZONTAL_FLIP_MAP: [Character: Character] = [
    "◀": "▶", "▶": "◀",
    "◁": "▷", "▷": "◁",
    "<": ">", ">": "<",
    "┌": "┐", "┐": "┌",
    "└": "┘", "┘": "└",
    "├": "┤", "┤": "├",
    "╭": "╮", "╮": "╭",
    "╰": "╯", "╯": "╰",
    "◤": "◢", "◢": "◤",
    "◥": "◣", "◣": "◥",
    "╴": "╶", "╶": "╴",
]

@discardableResult
public func flipCanvasHorizontally(_ canvas: inout Canvas) -> Canvas {
    for i in canvas.indices {
        canvas[i].reverse()
        for y in canvas[i].indices {
            if let mapped = HORIZONTAL_FLIP_MAP[canvas[i][y]] {
                canvas[i][y] = mapped
            }
        }
    }
    return canvas
}

@discardableResult
public func flipRoleCanvasHorizontally(_ roleCanvas: inout RoleCanvas) -> RoleCanvas {
    for i in roleCanvas.indices {
        roleCanvas[i].reverse()
    }
    return roleCanvas
}

public func drawText(_ canvas: inout Canvas, start: DrawingCoord, text: String, forceOverwrite: Bool = false) {
    _ = increaseSize(&canvas, start.x + max(0, terminalDisplayWidth(text)), start.y)
    for (i, ch) in text.enumerated() {
        let x = start.x + i
        guard x >= 0, x < canvas.count, start.y >= 0, start.y < (canvas.first?.count ?? 0) else { continue }
        if forceOverwrite || canvas[x][start.y] == " " {
            canvas[x][start.y] = ch
        }
    }
}

public func setCanvasSizeToGrid(
    _ canvas: inout Canvas,
    _ columnWidth: [Int: Int],
    _ rowHeight: [Int: Int]
) {
    let maxX = columnWidth.values.reduce(0, +)
    let maxY = rowHeight.values.reduce(0, +)
    _ = increaseSize(&canvas, maxX - 1, maxY - 1)
}

public func setRoleCanvasSizeToGrid(
    _ roleCanvas: inout RoleCanvas,
    _ columnWidth: [Int: Int],
    _ rowHeight: [Int: Int]
) {
    let maxX = columnWidth.values.reduce(0, +)
    let maxY = rowHeight.values.reduce(0, +)
    _ = increaseRoleCanvasSize(&roleCanvas, maxX - 1, maxY - 1)
}

