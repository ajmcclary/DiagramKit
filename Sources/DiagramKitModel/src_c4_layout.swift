import Foundation

// MARK: - C4 Layout Engine (Row-based, mirrors Mermaid's Bounds class)

private final class Bounds {
    var name: String = ""
    var data = BoundsData()
    var nextData = NextData()

    struct BoundsData {
        var startx: Double?
        var stopx: Double?
        var starty: Double?
        var stopy: Double?
        var widthLimit: Double?
    }

    struct NextData {
        var startx: Double?
        var stopx: Double?
        var starty: Double?
        var stopy: Double?
        var cnt: Int = 0
    }

    func setData(startx: Double, stopx: Double, starty: Double, stopy: Double) {
        nextData.startx = startx
        data.startx = startx
        nextData.stopx = stopx
        data.stopx = stopx
        nextData.starty = starty
        data.starty = starty
        nextData.stopy = stopy
        data.stopy = stopy
    }

    func updateVal(keyPath: WritableKeyPath<BoundsData, Double?>, val: Double, fun: (Double, Double) -> Double) {
        if data[keyPath: keyPath] == nil {
            data[keyPath: keyPath] = val
        } else {
            data[keyPath: keyPath] = fun(val, data[keyPath: keyPath]!)
        }
    }

    func insert(shape: inout PositionedC4Shape, maxInRow: Int) {
        nextData.cnt += 1
        var _startx: Double
        if nextData.startx == nextData.stopx {
            _startx = (nextData.stopx ?? 0) + shape.margin
        } else {
            _startx = (nextData.stopx ?? 0) + shape.margin * 2
        }
        var _stopx = _startx + shape.width
        var _starty = (nextData.starty ?? 0) + shape.margin * 2
        var _stopy = _starty + shape.height

        let limit = data.widthLimit ?? 6000
        if _startx >= limit || _stopx >= limit || nextData.cnt > maxInRow {
            _startx = (nextData.startx ?? 0) + shape.margin
            _starty = (nextData.stopy ?? 0) + shape.margin * 2
            _stopx = _startx + shape.width
            _stopy = _starty + shape.height
            nextData.stopx = _stopx
            nextData.starty = nextData.stopy
            nextData.stopy = _stopy
            nextData.cnt = 1
        }

        shape.x = _startx
        shape.y = _starty

        updateVal(keyPath: \.startx, val: _startx, fun: min)
        updateVal(keyPath: \.starty, val: _starty, fun: min)
        updateVal(keyPath: \.stopx, val: _stopx, fun: max)
        updateVal(keyPath: \.stopy, val: _stopy, fun: max)

        nextData.startx = min(nextData.startx ?? _startx, _startx)
        nextData.starty = min(nextData.starty ?? _starty, _starty)
        nextData.stopx = max(nextData.stopx ?? _stopx, _stopx)
        nextData.stopy = max(nextData.stopy ?? _stopy, _stopy)
    }

    func bumpLastMargin(_ margin: Double) {
        data.stopx = (data.stopx ?? 0) + margin
        data.stopy = (data.stopy ?? 0) + margin
    }
}

/// Layout a parsed C4 diagram into positioned output.
public func layoutC4Diagram(_ diagram: C4Diagram) -> PositionedC4Diagram {
    let config = diagram.config
    let c4ShapeInRow = config.c4ShapeInRow

    var positionedShapes: [PositionedC4Shape] = []
    var positionedBoundaries: [PositionedC4Boundary] = []
    var positionedRels: [PositionedC4Relationship] = []

    let screenBounds = Bounds()
    screenBounds.setData(
        startx: config.diagramMarginX,
        stopx: config.diagramMarginX,
        starty: config.diagramMarginY,
        stopy: config.diagramMarginY
    )
    screenBounds.data.widthLimit = 6000 // screen.availWidth equivalent

    var globalBoundaryMaxX = config.diagramMarginX
    var globalBoundaryMaxY = config.diagramMarginY

    // Process top-level boundaries
    let topBoundaries = diagram.boundaries.filter { $0.parentBoundary == "global" && $0.alias != "global" }

    // Draw shapes at global level first
    let globalShapes = diagram.shapes.filter { $0.parentBoundary == "global" }
    if !globalShapes.isEmpty {
        for shape in globalShapes {
            var pos = _computeShapePosition(shape, config: config, boundaryStartX: screenBounds.data.startx ?? config.diagramMarginX, boundaryStartY: screenBounds.data.starty ?? config.diagramMarginY)
            screenBounds.insert(shape: &pos, maxInRow: c4ShapeInRow)
            positionedShapes.append(pos)
            globalBoundaryMaxX = max(globalBoundaryMaxX, pos.x + pos.width)
            globalBoundaryMaxY = max(globalBoundaryMaxY, pos.y + pos.height)
        }
        screenBounds.bumpLastMargin(config.c4ShapeMargin)
    }

    // Draw inside each boundary recursively
    _drawInsideBoundary(
        parentAlias: "global",
        parentBounds: screenBounds,
        currentBoundaries: topBoundaries,
        allShapes: diagram.shapes,
        allBoundaries: diagram.boundaries,
        config: config,
        positionedShapes: &positionedShapes,
        positionedBoundaries: &positionedBoundaries,
        globalMaxX: &globalBoundaryMaxX,
        globalMaxY: &globalBoundaryMaxY
    )

    // Compute relationship positions
    positionedRels = _layoutRelationships(diagram.relationships, shapes: positionedShapes, boundaries: positionedBoundaries, diagramKind: diagram.kind, config: config)

    // Viewport
    let boxWidth = globalBoundaryMaxX - config.diagramMarginX
    let boxHeight = globalBoundaryMaxY - config.diagramMarginY
    let width = boxWidth + 2 * config.diagramMarginX
    let height = boxHeight + 2 * config.diagramMarginY

    return PositionedC4Diagram(
        width: width,
        height: height,
        shapes: positionedShapes,
        boundaries: positionedBoundaries,
        relationships: positionedRels,
        title: diagram.title,
        accTitle: diagram.title, // Mermaid quirk: accTitle stored as title
        accDescr: diagram.accDescr
    )
}

// MARK: - Recursive boundary layout

private func _drawInsideBoundary(
    parentAlias: String,
    parentBounds: Bounds,
    currentBoundaries: [C4Boundary],
    allShapes: [C4Shape],
    allBoundaries: [C4Boundary],
    config: C4DiagramConfig,
    positionedShapes: inout [PositionedC4Shape],
    positionedBoundaries: inout [PositionedC4Boundary],
    globalMaxX: inout Double,
    globalMaxY: inout Double
) {
    let c4BoundaryInRow = config.c4BoundaryInRow

    for (i, currentBoundary) in currentBoundaries.enumerated() {
        let currentBounds = Bounds()
        currentBounds.data.widthLimit = (parentBounds.data.widthLimit ?? 6000) / Double(min(c4BoundaryInRow, currentBoundaries.count))

        // Measure boundary header
        let labelConf = _boundaryLabelConf(config)
        let labelSize = _measureText(currentBoundary.label, fontSize: labelConf.size + 2, bold: true)
        let labelHeight = labelSize.height + _lineHeight(fontSize: labelConf.size)

        var typeHeight: Double = 0
        var descrHeight: Double = 0

        if let type = currentBoundary.type, !type.isEmpty {
            let typeText = "[\(type)]"
            let typeConf = _boundaryFont(config)
            let typeSize = _measureText(typeText, fontSize: typeConf.size, bold: false)
            typeHeight = typeSize.height + 5
        }

        if let descr = currentBoundary.description, !descr.isEmpty {
            let descrConf = _boundaryFont(config)
            let descrSize = _measureText(descr, fontSize: descrConf.size - 2, bold: false)
            descrHeight = descrSize.height + 20
        }

        let headerHeight = labelHeight + typeHeight + descrHeight + 8

        // Position boundary
        if i == 0 || i % c4BoundaryInRow == 0 {
            let x = parentBounds.data.startx ?? config.diagramMarginX
            let y = (parentBounds.data.stopy ?? config.diagramMarginY) + config.diagramMarginY + headerHeight
            currentBounds.setData(startx: x, stopx: x, starty: y, stopy: y)
        } else {
            let x = (currentBounds.data.stopx != currentBounds.data.startx)
                ? (currentBounds.data.stopx ?? 0) + config.diagramMarginX
                : currentBounds.data.startx ?? 0
            let y = currentBounds.data.starty ?? 0
            currentBounds.setData(startx: x, stopx: x, starty: y, stopy: y)
        }

        // Draw shapes inside boundary
        let innerShapes = allShapes.filter { $0.parentBoundary == currentBoundary.alias }
        for shape in innerShapes {
            var pos = _computeShapePosition(shape, config: config, boundaryStartX: currentBounds.data.startx ?? 0, boundaryStartY: currentBounds.data.starty ?? 0)
            currentBounds.insert(shape: &pos, maxInRow: config.c4ShapeInRow)
            positionedShapes.append(pos)
        }
        currentBounds.bumpLastMargin(config.c4ShapeMargin)

        // Recursively draw child boundaries
        let childBoundaries = allBoundaries.filter { $0.parentBoundary == currentBoundary.alias }
        if !childBoundaries.isEmpty {
            _drawInsideBoundary(
                parentAlias: currentBoundary.alias,
                parentBounds: currentBounds,
                currentBoundaries: childBoundaries,
                allShapes: allShapes,
                allBoundaries: allBoundaries,
                config: config,
                positionedShapes: &positionedShapes,
                positionedBoundaries: &positionedBoundaries,
                globalMaxX: &globalMaxX,
                globalMaxY: &globalMaxY
            )
        }

        // Create positioned boundary
        let bx = currentBounds.data.startx ?? 0
        let by = (currentBounds.data.starty ?? 0) - headerHeight
        let bw = (currentBounds.data.stopx ?? 0) - (currentBounds.data.startx ?? 0)
        let bh = (currentBounds.data.stopy ?? 0) - (currentBounds.data.starty ?? 0) + headerHeight

        let posBoundary = PositionedC4Boundary(
            alias: currentBoundary.alias,
            label: currentBoundary.label,
            type: currentBoundary.type,
            description: currentBoundary.description,
            nodeType: currentBoundary.nodeType,
            x: bx,
            y: by,
            width: max(bw, 50),
            height: max(bh, 50),
            labelY: 0,
            labelWidth: labelSize.width,
            labelHeight: labelSize.height,
            typeY: labelHeight,
            typeWidth: 0,
            typeHeight: typeHeight,
            descrY: labelHeight + typeHeight,
            descrWidth: 0,
            descrHeight: descrHeight,
            bgColor: currentBoundary.bgColor,
            fontColor: currentBoundary.fontColor,
            borderColor: currentBoundary.borderColor,
            wrap: currentBoundary.wrap
        )
        positionedBoundaries.append(posBoundary)

        // Update parent bounds
        parentBounds.data.stopy = max((currentBounds.data.stopy ?? 0) + config.c4ShapeMargin, parentBounds.data.stopy ?? 0)
        parentBounds.data.stopx = max((currentBounds.data.stopx ?? 0) + config.c4ShapeMargin, parentBounds.data.stopx ?? 0)
        globalMaxX = max(globalMaxX, parentBounds.data.stopx ?? 0)
        globalMaxY = max(globalMaxY, parentBounds.data.stopy ?? 0)
    }
}

// MARK: - Shape position computation

private func _computeShapePosition(
    _ shape: C4Shape,
    config: C4DiagramConfig,
    boundaryStartX: Double,
    boundaryStartY: Double
) -> PositionedC4Shape {
    var Y: Double = 0
    let shapeFontConf = config.font(for: shape.typeC4Shape)

    // Stereotype: <<Type>>
    let stereotypeText = "\u{00AB}\(shape.typeC4Shape.rawValue)\u{00BB}"
    let stereotypeSize = _measureText(stereotypeText, fontSize: shapeFontConf.size - 2, bold: false)
    let stereotypeH = stereotypeSize.height + 2
    let stereotypeY = config.c4ShapePadding
    Y = stereotypeY + stereotypeH - 4

    // Image space (person/external_person or sprite)
    var imageH: Double = 0
    var imageY: Double = 0
    switch shape.typeC4Shape {
    case .person, .external_person:
        imageH = 48
        imageY = Y
        Y += imageH
    default:
        break
    }
    if shape.sprite != nil {
        imageH = 48
        imageY = Y
        Y += imageH
    }

    // Label
    let labelConf = shapeFontConf
    let labelSize = _measureText(shape.label, fontSize: labelConf.size + 2, bold: true)
    let labelY = Y + 8
    Y = labelY + labelSize.height

    // Technology/Type
    var technY: Double = 0
    var technH: Double = 0
    var technW: Double = 0
    if let techn = shape.technology, !techn.isEmpty {
        let technText = "[\(techn)]"
        let technSize = _measureText(technText, fontSize: shapeFontConf.size, bold: false)
        technY = Y + 5
        technH = technSize.height
        technW = technSize.width
        Y = technY + technH
    }

    // Description
    var descrY: Double = 0
    var descrH: Double = 0
    var descrW: Double = 0
    if let descr = shape.description, !descr.isEmpty {
        let descrSize = _measureText(descr, fontSize: shapeFontConf.size, bold: false)
        descrY = Y + 20
        descrH = descrSize.height
        descrW = descrSize.width
        Y = descrY + descrH
    }

    let rectH = Y
    var rectW = labelSize.width

    rectW += config.c4ShapePadding * 2
    let shapeW = max(config.width, rectW, 200)
    let shapeH = max(config.height, rectH, 100)

    return PositionedC4Shape(
        alias: shape.alias,
        typeC4Shape: shape.typeC4Shape,
        label: shape.label,
        technology: shape.technology,
        description: shape.description,
        x: 0, y: 0, // Will be set by Bounds.insert
        width: shapeW,
        height: shapeH,
        margin: config.c4ShapeMargin,
        labelY: labelY,
        labelWidth: labelSize.width,
        labelHeight: labelSize.height,
        technY: technY,
        technWidth: technW,
        technHeight: technH,
        descrY: descrY,
        descrWidth: descrW,
        descrHeight: descrH,
        imageY: imageY,
        imageWidth: imageH > 0 ? 48 : 0,
        imageHeight: imageH,
        stereotypeY: stereotypeY,
        stereotypeWidth: stereotypeSize.width,
        stereotypeHeight: stereotypeH,
        bgColor: shape.bgColor,
        fontColor: shape.fontColor,
        borderColor: shape.borderColor,
        wrap: shape.wrap
    )
}

// MARK: - Relationship layout

private func _layoutRelationships(
    _ rels: [C4Relationship],
    shapes: [PositionedC4Shape],
    boundaries: [PositionedC4Boundary],
    diagramKind: C4DiagramKind,
    config: C4DiagramConfig
) -> [PositionedC4Relationship] {
    var positioned: [PositionedC4Relationship] = []

    for (index, rel) in rels.enumerated() {
        // Find source and target shapes
        guard let fromShape = shapes.first(where: { $0.alias == rel.from }),
              let toShape = shapes.first(where: { $0.alias == rel.to }) else {
            continue
        }

        let startCenter = CGPoint(x: fromShape.x + fromShape.width / 2, y: fromShape.y + fromShape.height / 2)
        let endCenter = CGPoint(x: toShape.x + toShape.width / 2, y: toShape.y + toShape.height / 2)

        let startPt = _getIntersectPoint(fromNode: fromShape, endPoint: endCenter) ?? startCenter
        let endPt = _getIntersectPoint(fromNode: toShape, endPoint: startCenter) ?? endCenter

        let dynamicIndex = diagramKind == .dynamic ? index + 1 : nil
        var displayLabel = rel.label
        if let idx = dynamicIndex {
            displayLabel = "\(idx): \(rel.label)"
        }

        let labelSize = _measureText(displayLabel, fontSize: config.messageFontSize, bold: false)
        let ox = Double(rel.offsetX ?? 0)
        let oy = Double(rel.offsetY ?? 0)
        let midX = (startPt.x + endPt.x) / 2 + ox
        let midY = (startPt.y + endPt.y) / 2 + oy

        var technX: Double = 0
        var technY: Double = 0
        var technW: Double = 0
        var technH: Double = 0
        if let techn = rel.technology, !techn.isEmpty {
            let technSize = _measureText("[\(techn)]", fontSize: config.messageFontSize, bold: false)
            technX = midX
            technY = midY + config.messageFontSize + 5
            technW = technSize.width
            technH = technSize.height
        }

        let posRel = PositionedC4Relationship(
            kind: rel.kind,
            from: rel.from,
            to: rel.to,
            label: displayLabel,
            technology: rel.technology,
            startPoint: startPt,
            endPoint: endPt,
            labelX: midX,
            labelY: midY,
            labelWidth: labelSize.width,
            labelHeight: labelSize.height,
            technX: technX,
            technY: technY,
            technWidth: technW,
            technHeight: technH,
            textColor: rel.textColor,
            lineColor: rel.lineColor,
            offsetX: rel.offsetX,
            offsetY: rel.offsetY,
            dynamicIndex: dynamicIndex
        )
        positioned.append(posRel)
    }

    return positioned
}

// MARK: - Intersection Point Algorithm (Mermaid's getIntersectPoint)

private func _getIntersectPoint(fromNode: PositionedC4Shape, endPoint: CGPoint) -> CGPoint? {
    let x1 = fromNode.x
    let y1 = fromNode.y
    let x2 = Double(endPoint.x)
    let y2 = Double(endPoint.y)
    let fromCenterX = x1 + fromNode.width / 2
    let fromCenterY = y1 + fromNode.height / 2
    let dx = abs(x1 - x2)
    let dy = abs(y1 - y2)
    let tanDYX = dx > 0 ? dy / dx : Double.infinity
    let fromDYX = fromNode.width > 0 ? fromNode.height / fromNode.width : Double.infinity

    // Axis-aligned cases
    if abs(y1 - y2) < 0.001 && x1 < x2 {
        return CGPoint(x: x1 + fromNode.width, y: fromCenterY)
    }
    if abs(y1 - y2) < 0.001 && x1 > x2 {
        return CGPoint(x: x1, y: fromCenterY)
    }
    if abs(x1 - x2) < 0.001 && y1 < y2 {
        return CGPoint(x: fromCenterX, y: y1 + fromNode.height)
    }
    if abs(x1 - x2) < 0.001 && y1 > y2 {
        return CGPoint(x: fromCenterX, y: y1)
    }

    // Quadrant cases
    if x1 > x2 && y1 < y2 {
        if fromDYX >= tanDYX {
            return CGPoint(x: x1, y: fromCenterY + (tanDYX * fromNode.width) / 2)
        } else {
            return CGPoint(x: fromCenterX - ((dx / dy) * fromNode.height) / 2, y: y1 + fromNode.height)
        }
    } else if x1 < x2 && y1 < y2 {
        if fromDYX >= tanDYX {
            return CGPoint(x: x1 + fromNode.width, y: fromCenterY + (tanDYX * fromNode.width) / 2)
        } else {
            return CGPoint(x: fromCenterX + ((dx / dy) * fromNode.height) / 2, y: y1 + fromNode.height)
        }
    } else if x1 < x2 && y1 > y2 {
        if fromDYX >= tanDYX {
            return CGPoint(x: x1 + fromNode.width, y: fromCenterY - (tanDYX * fromNode.width) / 2)
        } else {
            return CGPoint(x: fromCenterX + ((fromNode.height / 2) * dx) / dy, y: y1)
        }
    } else if x1 > x2 && y1 > y2 {
        if fromDYX >= tanDYX {
            return CGPoint(x: x1, y: fromCenterY - (fromNode.width / 2) * tanDYX)
        } else {
            return CGPoint(x: fromCenterX - ((fromNode.height / 2) * dx) / dy, y: y1)
        }
    }

    return nil
}

// MARK: - Text Measurement Helpers

private func _measureText(_ text: String, fontSize: Double, bold: Bool) -> CGSize {
    guard !text.isEmpty else { return .zero }
    let lines = text.components(separatedBy: "<br/>")
    var maxWidth: Double = 0
    var totalHeight: Double = 0
    for line in lines {
        let width = Double(line.count) * fontSize * 0.6 // rough estimate
        maxWidth = max(maxWidth, width)
        totalHeight += fontSize * 1.4
    }
    if totalHeight == 0 { totalHeight = fontSize * 1.4 }
    return CGSize(width: maxWidth, height: totalHeight)
}

private func _lineHeight(fontSize: Double) -> Double {
    fontSize * 1.4
}

private func _boundaryLabelConf(_ config: C4DiagramConfig) -> (family: String, size: Double, weight: String) {
    (config.boundaryFontFamily, config.boundaryFontSize, config.boundaryFontWeight)
}

private func _boundaryFont(_ config: C4DiagramConfig) -> (family: String, size: Double, weight: String) {
    (config.boundaryFontFamily, config.boundaryFontSize, config.boundaryFontWeight)
}
