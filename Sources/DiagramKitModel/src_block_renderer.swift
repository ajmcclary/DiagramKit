import Foundation
import DiagramKitCommon

public func renderBlockSvg(_ diagram: PositionedBlockDiagram, colors: DiagramColors, fontFamily: String = "Inter", transparent: Bool = false) throws -> String {
    try renderBlockSvg(diagram, diagramId: "mermaid-0", colors: colors, fontFamily: fontFamily, transparent: transparent)
}

public func renderBlockSvg(
    _ diagram: PositionedBlockDiagram,
    diagramId: String,
    colors: DiagramColors,
    fontFamily: String = "Inter",
    transparent: Bool = false
) throws -> String {
    var svg = ""

    let magicFactor = max(1.0, round(0.125 * (diagram.bounds.width / max(1, diagram.bounds.height))))
    let viewBoxX = diagram.bounds.x - 5
    let viewBoxY = diagram.bounds.y - 5
    let viewBoxW = diagram.bounds.width + 10
    let viewBoxH = diagram.bounds.height + magicFactor + 10

    let width = viewBoxW + 10
    let markerIds = BlockMarkerIds(diagramId: diagramId)

    let _viewBoxWFmt = viewBoxW.rounded() == viewBoxW ? String(Int(viewBoxW)) : String(viewBoxW)
    let _builder = SVGDocumentBuilder(
        width: viewBoxW, height: viewBoxH,
        colors: colors, transparent: transparent,
        fontFamily: fontFamily,
        accessibilityTitle: diagram.accTitle,
        accessibilityDescription: diagram.accDescr,
        viewBoxX: viewBoxX, viewBoxY: viewBoxY
    )
    var _openTag = _builder.open(extraAttributes: "id=\"\(SVG.escapeAttribute(diagramId))\"")
    _openTag = _openTag.replacingOccurrences(of: "width=\"\(_viewBoxWFmt)\"", with: "width=\"\(Int(width))\"")
    svg += _openTag + "\n"

    let accessibilityMarkup = _builder.accessibility()
    if !accessibilityMarkup.isEmpty {
        svg += accessibilityMarkup
    }

    if !transparent {
        svg += """
        <rect width="100%" height="100%" fill="\(colors.bg)"/>
        """
    }

    svg += renderBlockStyles(colors: colors, fontFamily: fontFamily)

    let markerLineColor = colors.line ?? "#333"
    let pointMarker = BlockEdgeArrowheadKind.point.svgMarkerBlock(id: markerIds.point, lineColor: markerLineColor)!
    let circleMarker = BlockEdgeArrowheadKind.circle.svgMarkerBlock(id: markerIds.circle, lineColor: markerLineColor)!
    let crossMarker = BlockEdgeArrowheadKind.cross.svgMarkerBlock(id: markerIds.cross, lineColor: markerLineColor)!
    svg += """
    <defs>
    \(pointMarker)
    \(circleMarker)
    \(crossMarker)
    </defs>
    """

    svg += """
    <g class="block">
    """

    for block in diagram.blocks {
        svg += renderBlockNodeSvg(block, colors: colors, fontFamily: fontFamily)
    }

    for edge in diagram.edges {
        svg += renderBlockEdgeSvg(edge, colors: colors, fontFamily: fontFamily, markerIds: markerIds)
    }

    svg += """
    </g>
    """
    svg += _builder.close() + "\n"
    return svg
}

private func renderBlockStyles(colors: DiagramColors, fontFamily: String) -> String {
    let mainBkg = colors.surface ?? colors.bg
    let nodeBorder = colors.border ?? colors.line ?? "#333"
    let nodeTextColor = colors.fg
    let lineColor = colors.line ?? colors.border ?? "#333"
    let edgeLabelBg = colors.surface ?? colors.bg
    let arrowheadColor = colors.line ?? colors.fg
    let clusterBkg = colors.surface ?? colors.bg
    let clusterBorder = colors.border ?? "#333"
    let titleColor = colors.fg

    return """
    <style>
    .label {
        font-family: \(fontFamily);
        color: \(nodeTextColor);
    }
    .cluster-label text {
        fill: \(titleColor);
    }
    .cluster-label span,p {
        color: \(titleColor);
    }
    .label text,span,p {
        fill: \(nodeTextColor);
        color: \(nodeTextColor);
    }
    .node rect,
    .node circle,
    .node ellipse,
    .node polygon,
    .node path {
        fill: \(mainBkg);
        stroke: \(nodeBorder);
        stroke-width: 1px;
    }
    .flowchart-label text {
        text-anchor: middle;
    }
    .node .label {
        text-align: center;
    }
    .node.clickable {
        cursor: pointer;
    }
    .arrowheadPath {
        fill: \(arrowheadColor);
    }
    .edgePath .path {
        stroke: \(lineColor);
        stroke-width: 2.0px;
    }
    .flowchart-link {
        stroke: \(lineColor);
        fill: none;
    }
    .edgeLabel {
        background-color: \(edgeLabelBg);
        text-align: center;
    }
    .edgeLabel rect {
        opacity: 0.5;
        background-color: \(edgeLabelBg);
        fill: \(edgeLabelBg);
    }
    .labelBkg {
        background-color: \(edgeLabelBg);
    }
    .node .cluster {
        fill: \(clusterBkg);
        stroke: \(clusterBorder);
        stroke-width: 1px;
    }
    .cluster text {
        fill: \(titleColor);
    }
    .flowchartTitleText {
        text-anchor: middle;
        font-size: 18px;
        fill: \(colors.fg);
    }
    </style>
    """
}

private struct BlockMarkerIds {
    let point: String
    let circle: String
    let cross: String

    init(diagramId: String) {
        point = "\(diagramId)-block-point"
        circle = "\(diagramId)-block-circle"
        cross = "\(diagramId)-block-cross"
    }
}

private func renderBlockNodeSvg(_ node: PositionedBlockNode, colors: DiagramColors, fontFamily: String) -> String {
    if node.type == .space || node.type == .columnSetting { return "" }

    let id = node.domId ?? "block-" + node.id
    let x = node.x - node.width / 2
    let y = node.y - node.height / 2
    let w = node.width
    let h = node.height

    let fill = resolveBlockFill(node, defaultFill: colors.surface ?? colors.bg)
    let stroke = resolveBlockStroke(node, defaultColor: colors.border ?? colors.line ?? "#333")
    let textColor = resolveBlockTextColor(node, defaultColor: colors.fg)

    let hasExplicitClasses = !node.classes.isEmpty
    let classList: [String] = hasExplicitClasses ? node.classes : ["default"]
    let fullClassList = (classList + ["flowchart-label"]).joined(separator: " ")

    if node.type == .composite {
        let clusterBkg = colors.surface ?? colors.bg
        let clusterBorder = colors.border ?? "#333"
        let full = DiagramRect(
            origin: DiagramPoint(x: x, y: y),
            size: DiagramSize(width: w, height: h)
        )
        let body = BlockClusterLayout.bodyRect(in: full)
        let title = BlockClusterLayout.titleBaseline(in: full)
        var svg = """
        <g class="cluster" id="\(id)">
          <rect x="\(body.x)" y="\(body.y)" width="\(body.width)" height="\(body.height)" rx="2" ry="2" fill="\(clusterBkg)" stroke="\(clusterBorder)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
          <text x="\(title.x)" y="\(title.y)" text-anchor="middle" font-family="\(fontFamily)" font-size="14" font-weight="bold" fill="\(textColor)">\(node.label.escapedXML)</text>
        """
        for child in node.children {
            svg += renderBlockNodeSvg(child, colors: colors, fontFamily: fontFamily)
        }
        svg += "</g>"
        return svg
    }

    if node.type == .blockArrow {
        var svg = renderBlockArrowSvg(node: node, id: id, fill: fill, stroke: stroke, classList: fullClassList)
        svg += renderBlockLabelSvg(label: node.label, x: node.x, y: node.y, color: textColor, fontFamily: fontFamily)
        return svg
    }

    var svg = """
    <g class="node \(fullClassList)" id="\(id)">
    """

    svg += _renderBlockShapeBody(
        node: node, x: x, y: y, w: w, h: h,
        fill: fill, stroke: stroke, colors: colors
    )

    svg += renderBlockLabelSvg(label: node.label, x: node.x, y: node.y, color: textColor, fontFamily: fontFamily)
    svg += "</g>"
    return svg
}

/// Routes block-node shape rendering through `ShapeSpecRegistry` +
/// `SVGPathSerializer` so the SVG renderer agrees with `DiagramRenderer+Block`
/// on every shape's geometry (audit D2). Falls back to a plain rectangle
/// when no spec resolves — `BlockShapeMapper` is total over the user-facing
/// block shape set, so the fallback is reserved for future enum cases.
private func _renderBlockShapeBody(
    node: PositionedBlockNode,
    x: Double, y: Double, w: Double, h: Double,
    fill: String, stroke: String,
    colors: DiagramColors
) -> String {
    let strokeWidth = BlockRenderConstants.strokeWidth
    let aliasName = BlockShapeMapper.shapeSpecName(for: node.type)
    let bounds = CGRect(x: x, y: y, width: w, height: h)
    let config = RenderConfig.shared

    let spec = ShapeSpecRegistry.spec(for: aliasName)

    var parts: [String] = []
    let mainD = SVGPathSerializer.serialize(spec.path(bounds, config), in: bounds)
    parts.append(
        "  <path d=\"\(mainD)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(strokeWidth)\"/>"
    )
    for decoration in spec.decorations {
        let decBounds = decoration.bounds(bounds, config)
        let decPath = decoration.path(decBounds, config)
        let decD = SVGPathSerializer.serialize(decPath, in: decBounds)
        let decFill: String
        switch decoration.fill {
        case .none:       decFill = "none"
        case .inherit:    decFill = fill
        case .surface:    decFill = colors.surface ?? colors.bg
        case .foreground: decFill = colors.fg
        }
        var decStroke = stroke
        var dashAttr = ""
        switch decoration.stroke {
        case .none:
            decStroke = "none"
        case .mainStroke, .thinStroke:
            break
        case .dashed(let lengths):
            dashAttr = " stroke-dasharray=\"" + lengths.map { String(describing: $0) }.joined(separator: " ") + "\""
        }
        parts.append(
            "  <path d=\"\(decD)\" fill=\"\(decFill)\" stroke=\"\(decStroke)\" stroke-width=\"\(strokeWidth)\"\(dashAttr)/>"
        )
    }
    return parts.joined()
}

private func renderBlockArrowSvg(node: PositionedBlockNode, id: String, fill: String, stroke: String, classList: String) -> String {
    let w = node.width
    let h = node.height
    let padding = 8.0
    let dirs = node.directions ?? [.right]
    let points = getBlockArrowPoints(directions: dirs, width: w, height: h, padding: padding)

    let minX = points.map(\.x).min() ?? 0
    let maxX = points.map(\.x).max() ?? CGFloat(w)
    let minY = points.map(\.y).min() ?? -CGFloat(h)
    let maxY = points.map(\.y).max() ?? 0
    let centerX = (minX + maxX) / 2
    let centerY = (minY + maxY) / 2

    let pathStr = points.enumerated().map { (i, p) in
        let x = p.x - centerX
        let y = p.y - centerY
        return i == 0 ? "M \(x),\(y)" : "L \(x),\(y)"
    }.joined(separator: " ") + " Z"

    return """
    <g class="node \(classList)" id="\(id)" transform="translate(\(node.x) \(node.y))">
      <path d="\(pathStr)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
    </g>
    """
}

private func renderBlockLabelSvg(label: String, x: Double, y: Double, color: String, fontFamily: String) -> String {
    guard !label.isEmpty else { return "" }
    return """
      <text x="\(x)" y="\(y)" text-anchor="middle" dominant-baseline="central" font-family="\(fontFamily)" font-size="12" fill="\(color)">\(label.escapedXML)</text>
    """
}

private func renderBlockEdgeSvg(_ edge: PositionedBlockEdge, colors: DiagramColors, fontFamily: String, markerIds: BlockMarkerIds) -> String {
    guard edge.points.count >= 3 else { return "" }
    let pts = edge.points

    let thicknessClass = edge.thickness == "thick" ? "edge-thickness-thick" : "edge-thickness-normal"
    let patternClass = edge.pattern == "dotted" ? "edge-pattern-dotted" : "edge-pattern-solid"
    let cssClasses = "\(thicknessClass) \(patternClass) flowchart-link"

    let strokeWidth = edge.thickness == "thick"
        ? String(BlockRenderConstants.thickStrokeWidth)
        : String(BlockRenderConstants.strokeWidth)
    let dashArray = edge.pattern == "dotted" ? "stroke-dasharray: 5,5;" : ""

    let markerStart = blockMarkerAttribute(name: "marker-start", arrowType: edge.arrowTypeStart, markerIds: markerIds)
    let markerEnd = blockMarkerAttribute(name: "marker-end", arrowType: edge.arrowTypeEnd, markerIds: markerIds)

    let pathD = "M \(pts[0].x),\(pts[0].y) L \(pts[1].x),\(pts[1].y) L \(pts[2].x),\(pts[2].y)"

    let lineColor = colors.line ?? colors.border ?? "#333"
    var svg = """
    <g class="edgePath \(cssClasses)">
      <path class="path" d="\(pathD)" fill="none" stroke="\(lineColor)" stroke-width="\(strokeWidth)" style="\(dashArray)"\(markerStart)\(markerEnd)/>
    """

    if let label = edge.label, !label.isEmpty {
        let mid = DiagramPoint(x: pts[1].x, y: pts[1].y)
        let labelWidth = BlockEdgeLabelLayout.labelWidth(for: label)
        let bg = BlockEdgeLabelLayout.backgroundRect(at: mid, labelWidth: labelWidth)
        let baseline = BlockEdgeLabelLayout.textBaseline(at: mid)
        let labelBg = colors.surface ?? colors.bg
        svg += """
      <g class="edgeLabel">
        <rect x="\(bg.x)" y="\(bg.y)" width="\(bg.width)" height="\(bg.height)" rx="\(BlockEdgeLabelLayout.backgroundCornerRadius)" fill="\(labelBg)" opacity="0.5" stroke="none"/>
        <text x="\(baseline.x)" y="\(baseline.y)" text-anchor="middle" font-family="\(fontFamily)" font-size="12" fill="\(colors.fg)">\(label.escapedXML)</text>
      </g>
      """
    }

    svg += "</g>"
    return svg
}

private func blockMarkerAttribute(name: String, arrowType: String, markerIds: BlockMarkerIds) -> String {
    switch BlockEdgeArrowheadKind(rawArrowType: arrowType) {
    case .point:  return " \(name)=\"url(#\(markerIds.point))\""
    case .circle: return " \(name)=\"url(#\(markerIds.circle))\""
    case .cross:  return " \(name)=\"url(#\(markerIds.cross))\""
    case .none:   return ""
    }
}

public func blockNodeShapeName(_ type: BlockNodeType) -> String {
    switch type {
    case .square: return "rect"
    case .round: return "rect"
    case .circle: return "circle"
    case .doublecircle: return "doublecircle"
    case .diamond: return "diamond"
    case .hexagon: return "hexagon"
    case .stadium: return "stadium"
    case .subroutine: return "subroutine"
    case .cylinder: return "cylinder"
    case .leanRight: return "lean_right"
    case .leanLeft: return "lean_left"
    case .trapezoid: return "trapezoid"
    case .invTrapezoid: return "inv_trapezoid"
    case .rectLeftInvArrow: return "rect_left_inv_arrow"
    case .blockArrow: return "block_arrow"
    case .composite: return "composite"
    default: return "rect"
    }
}

private func resolveBlockFill(_ node: PositionedBlockNode, defaultFill: String) -> String {
    return BlockStyleDecoder.fillHex(from: node.styles) ?? defaultFill
}

private func resolveBlockStroke(_ node: PositionedBlockNode, defaultColor: String) -> String {
    return BlockStyleDecoder.strokeHex(from: node.styles) ?? defaultColor
}

private func resolveBlockTextColor(_ node: PositionedBlockNode, defaultColor: String) -> String {
    return BlockStyleDecoder.textColorHex(labelStyle: node.labelStyle, styles: node.styles) ?? defaultColor
}

extension String {
    var escapedXML: String {
        SVG.escapeText(self)
    }
}
