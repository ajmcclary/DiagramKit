import Foundation
import DiagramKitCommon

/// Concurrency Contract: `BlockWarnings` is the process-wide store
/// backing the public `blockWarnings()` / `resetBlockWarnings()`
/// surface for the block-diagram layout. Every `append` / `all` /
/// `reset` is wrapped in the internal `NSLock`, so concurrent layout
/// calls from worker threads can drain or reset the bag without
/// racing. The `@unchecked Sendable` annotation is sound. (Resolves
/// yellow → green per REVIEW.md L2.)
private final class BlockWarnings: @unchecked Sendable {
    private var warnings: [String] = []
    private let lock = NSLock()
    func append(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        warnings.append(message)
    }
    func all() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return warnings
    }
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        warnings.removeAll()
    }
}
private let _blockWarnings = BlockWarnings()
private let _blockCompositeHeaderHeight = 20.0

private func _blockHeaderHeight(_ block: BlockNode) -> Double {
    block.type == .composite && block.id != "root" ? _blockCompositeHeaderHeight : 0
}

public func blockWarnings() -> [String] { _blockWarnings.all() }
public func resetBlockWarnings() { _blockWarnings.reset() }

private func _blockLogWarning(_ message: String) {
    _blockWarnings.append(message)
}

private let BLOCK_FONT_SIZE: Double = 14
private let BLOCK_FONT_WEIGHT: Int = 400

public struct BlockShapeMetrics {
    let textPaddingX: Double
    let textPaddingY: Double
    let minWidth: Double
    let minHeight: Double

    static func forType(_ type: BlockNodeType) -> BlockShapeMetrics {
        switch type {
        case .square, .na, .round:
            return BlockShapeMetrics(textPaddingX: 20, textPaddingY: 12, minWidth: 40, minHeight: 30)
        case .circle, .doublecircle:
            return BlockShapeMetrics(textPaddingX: 24, textPaddingY: 24, minWidth: 40, minHeight: 40)
        case .diamond:
            return BlockShapeMetrics(textPaddingX: 28, textPaddingY: 28, minWidth: 50, minHeight: 50)
        case .hexagon:
            return BlockShapeMetrics(textPaddingX: 24, textPaddingY: 16, minWidth: 50, minHeight: 34)
        case .stadium:
            return BlockShapeMetrics(textPaddingX: 20, textPaddingY: 10, minWidth: 50, minHeight: 30)
        case .subroutine:
            return BlockShapeMetrics(textPaddingX: 24, textPaddingY: 12, minWidth: 60, minHeight: 30)
        case .cylinder:
            return BlockShapeMetrics(textPaddingX: 20, textPaddingY: 16, minWidth: 40, minHeight: 36)
        case .leanRight, .leanLeft, .trapezoid, .invTrapezoid:
            return BlockShapeMetrics(textPaddingX: 24, textPaddingY: 14, minWidth: 50, minHeight: 34)
        case .rectLeftInvArrow:
            return BlockShapeMetrics(textPaddingX: 22, textPaddingY: 12, minWidth: 56, minHeight: 30)
        case .blockArrow:
            return BlockShapeMetrics(textPaddingX: 24, textPaddingY: 14, minWidth: 60, minHeight: 36)
        case .composite:
            return BlockShapeMetrics(textPaddingX: 8, textPaddingY: 8, minWidth: 60, minHeight: 40)
        case .space, .columnSetting:
            return BlockShapeMetrics(textPaddingX: 0, textPaddingY: 0, minWidth: 20, minHeight: 30)
        case .edge, .classDef, .applyClass, .applyStyles:
            return BlockShapeMetrics(textPaddingX: 0, textPaddingY: 0, minWidth: 0, minHeight: 0)
        }
    }
}

private func measureBlockWidth(_ block: BlockNode) -> Double {
    let metrics = BlockShapeMetrics.forType(block.type)
    let textWidth = original_src_text_metrics.measureTextWidth(
        block.label.isEmpty ? block.id : block.label,
        fontSize: BLOCK_FONT_SIZE,
        fontWeight: BLOCK_FONT_WEIGHT
    )
    let totalWidth = textWidth + metrics.textPaddingX
    return max(metrics.minWidth, totalWidth)
}

private func measureBlockHeight(_ block: BlockNode) -> Double {
    let metrics = BlockShapeMetrics.forType(block.type)
    let lineHeight = BLOCK_FONT_SIZE * 1.3
    let textHeight = lineHeight + metrics.textPaddingY
    return max(metrics.minHeight, textHeight)
}

public func calculateBlockPosition(columns: Int, position: Int) -> (px: Int, py: Int) {
    if columns == 0 || position < 0 {
        return (px: 0, py: 0)
    }
    if columns < 0 {
        return (px: position, py: 0)
    }
    if columns == 1 {
        return (px: 0, py: position)
    }
    let px = position % columns
    let py = position / columns
    return (px, py)
}

private func getMaxChildSize(block: BlockNode, db: [String: BlockNode]) -> (width: Double, height: Double) {
    var maxWidth = 0.0
    var maxHeight = 0.0
    for childId in block.children {
        guard let child = db[childId], let size = child.size else { continue }
        if child.type == .space { continue }
        let normalizedWidth = size.width / Double(child.widthInColumns ?? 1)
        if normalizedWidth > maxWidth { maxWidth = normalizedWidth }
        if size.height > maxHeight { maxHeight = size.height }
    }
    return (maxWidth, maxHeight)
}

private func setBlockSizes(
    block: inout BlockNode,
    db: inout [String: BlockNode],
    siblingWidth: Double = 0,
    siblingHeight: Double = 0,
    padding: Double = 8
) {
    if block.size?.width == nil || block.size?.width == 0 {
        block.size = BlockSize(width: siblingWidth, height: siblingHeight, x: 0, y: 0)
    }

    guard !block.children.isEmpty else { return }

    for childId in block.children {
        if var child = db[childId] {
            setBlockSizes(block: &child, db: &db, padding: padding)
            db[childId] = child
        }
    }

    let childSize = getMaxChildSize(block: block, db: db)
    var maxWidth = childSize.width
    let maxHeight = childSize.height

    if maxWidth == 0 { maxWidth = 60 }
    let effectiveMaxHeight = maxHeight > 0 ? maxHeight : 40

    for childId in block.children {
        if var child = db[childId] {
            if child.size != nil {
                let parentCols = block.columns ?? -1
                let childSpan = child.widthInColumns ?? 1
                if parentCols > 0 && childSpan > parentCols {
                    _blockLogWarning("Block \(child.id) width \(childSpan) exceeds configured column width \(parentCols)")
                }
                child.size?.width = maxWidth * Double(child.widthInColumns ?? 1) + padding * Double((child.widthInColumns ?? 1) - 1)
                child.size?.height = effectiveMaxHeight
                child.size?.x = 0
                child.size?.y = 0
                db[childId] = child
            }
        }
    }

    for childId in block.children {
        if var child = db[childId] {
            setBlockSizes(block: &child, db: &db, siblingWidth: maxWidth, siblingHeight: effectiveMaxHeight, padding: padding)
            db[childId] = child
        }
    }

    let columns = block.columns ?? -1
    var numItems = 0
    for childId in block.children {
        if let child = db[childId] {
            numItems += child.widthInColumns ?? 1
        }
    }

    var xSize = block.children.count
    if columns > 0 && columns < numItems {
        xSize = columns
    }
    let ySize = max(1, Int(ceil(Double(numItems) / Double(xSize))))

    var width = Double(xSize) * (maxWidth + padding) + padding
    let headerHeight = _blockHeaderHeight(block)
    var height = headerHeight + Double(ySize) * (effectiveMaxHeight + padding) + padding

    if width < siblingWidth && siblingWidth > 0 {
        width = siblingWidth
        height = max(height, siblingHeight)
        let childWidth = (siblingWidth - Double(xSize) * padding - padding) / Double(xSize)
        let childAreaHeight = max(0, height - headerHeight)
        let childHeight = max(0, (childAreaHeight - Double(ySize) * padding - padding) / Double(ySize))
        for childId in block.children {
            if var child = db[childId] {
                child.size?.width = childWidth
                child.size?.height = childHeight
                child.size?.x = 0
                child.size?.y = 0
                db[childId] = child
            }
        }
    }

    if width < (block.size?.width ?? 0) {
        width = block.size?.width ?? 0
        let num = columns > 0 ? min(block.children.count, columns) : block.children.count
        if num > 0 {
            let childWidth = (width - Double(num) * padding - padding) / Double(num)
            for childId in block.children {
                if var child = db[childId] {
                    child.size?.width = childWidth
                    db[childId] = child
                }
            }
        }
    }

    block.size = BlockSize(width: width, height: height, x: 0, y: 0)
}

private func layoutBlocks(block: inout BlockNode, db: inout [String: BlockNode], padding: Double = 8) {
    let columns = block.columns ?? -1
    guard !block.children.isEmpty else { return }
    let headerHeight = _blockHeaderHeight(block)

    var rowHeights: [Int: Double] = [:]
    var colPos = 0
    for childId in block.children {
        guard let child = db[childId], let size = child.size else { continue }
        let (_, py) = calculateBlockPosition(columns: columns, position: colPos)
        let currentMax = rowHeights[py] ?? 0
        if size.height > currentMax { rowHeights[py] = size.height }
        var filled = child.widthInColumns ?? 1
        if columns > 0 { filled = min(filled, columns - (colPos % columns)) }
        colPos += filled
    }

    var rowYOffsets: [Int: Double] = [:]
    var offset = 0.0
    let rows = rowHeights.keys.sorted()
    for row in rows {
        rowYOffsets[row] = offset
        offset += (rowHeights[row] ?? 0) + padding
    }

    colPos = 0
    var startingPosX = (block.size?.x ?? 0) + (-(block.size?.width ?? 0) / 2)
    var rowPos = 0
    for childId in block.children {
        guard var child = db[childId], var size = child.size else { continue }
        let (_, py) = calculateBlockPosition(columns: columns, position: colPos)

        if py != rowPos {
            rowPos = py
            startingPosX = (block.size?.x ?? 0) + (-(block.size?.width ?? 0) / 2)
        }

        if let parentSize = block.size {
            let halfWidth = size.width / 2
            size.x = startingPosX + padding + halfWidth
            let rowYOffset = rowYOffsets[py] ?? 0
            let rowHeight = rowHeights[py] ?? size.height
            size.y = parentSize.y - parentSize.height / 2 + headerHeight + rowYOffset + rowHeight / 2 + padding

            startingPosX = size.x + halfWidth
        }

        child.size = size
        db[childId] = child

        if !child.children.isEmpty {
            if var childRef = db[childId] {
                layoutBlocks(block: &childRef, db: &db, padding: padding)
                db[childId] = childRef
            }
        }

        var columnsFilled = child.widthInColumns ?? 1
        if columns > 0 {
            columnsFilled = min(columnsFilled, columns - (colPos % columns))
        }
        colPos += columnsFilled
    }
}

private func findBounds(block: BlockNode, db: [String: BlockNode]) -> (minX: Double, minY: Double, maxX: Double, maxY: Double) {
    var minX = 0.0, minY = 0.0, maxX = 0.0, maxY = 0.0

    func collect(_ blk: BlockNode) {
        if let size = blk.size, blk.id != "root" {
            let x1 = size.x - size.width / 2
            let y1 = size.y - size.height / 2
            let x2 = size.x + size.width / 2
            let y2 = size.y + size.height / 2
            if x1 < minX { minX = x1 }
            if y1 < minY { minY = y1 }
            if x2 > maxX { maxX = x2 }
            if y2 > maxY { maxY = y2 }
        }
        for childId in blk.children {
            if let child = db[childId] { collect(child) }
        }
    }
    collect(block)
    return (minX, minY, maxX, maxY)
}

public func blockIntersect(
    center: CGPoint,
    size: BlockSize,
    type: BlockNodeType,
    target: CGPoint
) -> CGPoint {
    let dx = target.x - center.x
    let dy = target.y - center.y
    let hw = size.width / 2
    let hh = size.height / 2

    guard dx != 0 || dy != 0 else { return center }

    switch type {
    case .diamond:
        let absSlope = abs(dy) / max(abs(dx), 1e-6)
        if absSlope < hh / hw {
            let sx = dx > 0 ? hw : -hw
            return CGPoint(x: center.x + sx, y: center.y + (dy / abs(dx)) * abs(sx) * (hh / hw))
        } else {
            let sy = dy > 0 ? hh : -hh
            return CGPoint(x: center.x + (dx / abs(dy)) * abs(sy) * (hw / hh), y: center.y + sy)
        }
    case .hexagon:
        let absSlope = abs(dy) / max(abs(dx), 1e-6)
        let qw = size.width / 4
        let edgeSlope = hh / qw
        if absSlope < edgeSlope {
            let sx = dx > 0 ? hw : -hw
            let yOnEdge = (dy / abs(dx)) * abs(sx)
            if abs(yOnEdge) <= hh * 0.5 {
                return CGPoint(x: center.x + sx, y: center.y + yOnEdge * edgeSlope / absSlope)
            } else {
                let sy = dy > 0 ? hh : -hh
                return CGPoint(x: center.x + (dx / abs(dy)) * abs(sy) * (hw - qw/2) / hh, y: center.y + sy)
            }
        } else {
            let sy = dy > 0 ? hh : -hh
            return CGPoint(x: center.x + (dx / abs(dy)) * abs(sy) * (hw - qw/2) / hh, y: center.y + sy)
        }
    case .circle, .doublecircle:
        let r = (min(size.width, size.height) / 2)
        let angle = atan2(dy, dx)
        return CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
    case .stadium:
        if abs(dy) > abs(dx) {
            let sy = dy > 0 ? hh : -hh
            _ = min(hw, hh)
            return CGPoint(x: center.x, y: center.y + sy)
        }
        return rectIntersect(center: center, hw: hw, hh: hh, dx: dx, dy: dy)
    case .leanRight, .leanLeft, .trapezoid, .invTrapezoid, .rectLeftInvArrow, .blockArrow:
        fallthrough
    default:
        return rectIntersect(center: center, hw: hw, hh: hh, dx: dx, dy: dy)
    }
}

private func rectIntersect(center: CGPoint, hw: Double, hh: Double, dx: Double, dy: Double) -> CGPoint {
    let absSlope = abs(dy) / max(abs(dx), 1e-6)
    if absSlope < hh / hw {
        let sx = dx > 0 ? hw : -hw
        return CGPoint(x: center.x + sx, y: center.y + (dy / abs(dx)) * abs(sx) * (absSlope < hh / hw ? 1 : (hh / hw) / absSlope))
    } else {
        let sy = dy > 0 ? hh : -hh
        return CGPoint(x: center.x + (dx / abs(dy)) * abs(sy) * ((hh / hw) / absSlope), y: center.y + sy)
    }
}

public func layoutBlockDiagram(_ diagram: BlockDiagram) throws -> PositionedBlockDiagram {
    var db = diagram.blockDatabase
    let padding = diagram.config.padding

    guard var root = db["root"] else {
        throw DiagramError.notYetImplemented("Block Diagram layout: no root block")
    }

    for childId in root.children {
        if var child = db[childId] {
            let needsSize = child.size == nil || (child.size?.width ?? 0) == 0
            if needsSize {
                if child.type == .composite && !child.children.isEmpty {
                    child.size = BlockSize(width: 60, height: 40, x: 0, y: 0)
                } else {
                    let w = measureBlockWidth(child)
                    let h = measureBlockHeight(child)
                    child.size = BlockSize(width: w, height: h, x: 0, y: 0)
                }
                db[childId] = child
            }
        }
    }

    setBlockSizes(block: &root, db: &db, siblingWidth: 0, siblingHeight: 0, padding: padding)
    db["root"] = root

    guard var positionedRoot = db["root"] else {
        throw DiagramError.notYetImplemented("Block Diagram layout: root missing after sizing")
    }
    layoutBlocks(block: &positionedRoot, db: &db, padding: padding)
    db["root"] = positionedRoot

    let bounds = findBounds(block: positionedRoot, db: db)
    let diagramWidth = bounds.maxX - bounds.minX
    let diagramHeight = bounds.maxY - bounds.minY

    var positionedBlocks: [PositionedBlockNode] = []
    var positionedEdges: [PositionedBlockEdge] = []

    func buildPositioned(_ blk: BlockNode) -> PositionedBlockNode {
        let classes = blk.classes ?? []
        var styles: [String] = []
        var labelStyles: [String] = []
        for className in classes {
            if let classDef = diagram.classes[className] {
                styles.append(contentsOf: classDef.styles)
                labelStyles.append(contentsOf: classDef.textStyles)
            }
        }
        if let defaultClassDef = diagram.classes["default"] {
            styles.append(contentsOf: defaultClassDef.styles)
            labelStyles.append(contentsOf: defaultClassDef.textStyles)
        }
        styles.append(contentsOf: blk.styles ?? [])
        let size = blk.size ?? BlockSize()
        // Match the CG `rounded` ShapeRenderer corner radius (6 pt) so SVG
        // and CG agree for `.round` block nodes.
        let rounded = blk.type == .round ? 6.0 : 0.0
        return PositionedBlockNode(
            id: blk.id,
            label: blk.label,
            type: blk.type,
            x: size.x,
            y: size.y,
            width: size.width,
            height: size.height,
            children: blk.children.compactMap { db[$0] }.map { buildPositioned($0) },
            classes: classes,
            styles: styles,
            labelStyle: labelStyles.joined(separator: ";"),
            directions: blk.directions,
            rx: rounded,
            ry: rounded,
            domId: "block-" + blk.id
        )
    }

    for childId in positionedRoot.children {
        if let child = db[childId], child.type != .space {
            positionedBlocks.append(buildPositioned(child))
        }
    }

    for edge in diagram.edges {
        guard let startBlock = db[edge.start], let endBlock = db[edge.end],
              let startSize = startBlock.size, let endSize = endBlock.size else { continue }
        let startCenter = CGPoint(x: startSize.x, y: startSize.y)
        let endCenter = CGPoint(x: endSize.x, y: endSize.y)
        let startPoint = blockIntersect(center: startCenter, size: startSize, type: startBlock.type, target: endCenter)
        let endPoint = blockIntersect(center: endCenter, size: endSize, type: endBlock.type, target: startCenter)
        let midpoint = CGPoint(
            x: startPoint.x + (endPoint.x - startPoint.x) / 2,
            y: startPoint.y + (endPoint.y - startPoint.y) / 2
        )
        let points = [startPoint, midpoint, endPoint]
        positionedEdges.append(PositionedBlockEdge(
            id: edge.id,
            startId: edge.start,
            endId: edge.end,
            label: edge.label,
            points: points,
            thickness: edge.thickness,
            pattern: edge.pattern,
            arrowTypeEnd: edge.arrowTypeEnd,
            arrowTypeStart: edge.arrowTypeStart
        ))
    }

    return PositionedBlockDiagram(
        blocks: positionedBlocks,
        edges: positionedEdges,
        width: diagramWidth,
        height: diagramHeight,
        bounds: BlockBounds(x: bounds.minX, y: bounds.minY, width: diagramWidth, height: diagramHeight),
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        diagramTitle: diagram.diagramTitle
    )
}
