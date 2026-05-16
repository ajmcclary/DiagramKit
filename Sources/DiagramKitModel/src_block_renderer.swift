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

    svg += """
    <defs>
    <marker id="\(markerIds.point)" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="\(colors.line ?? "#333")"/>
    </marker>
    <marker id="\(markerIds.circle)" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <circle cx="5" cy="5" r="4" fill="none" stroke="\(colors.line ?? "#333")" stroke-width="1"/>
    </marker>
    <marker id="\(markerIds.cross)" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M 1 1 L 9 9 M 9 1 L 1 9" stroke="\(colors.line ?? "#333")" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
    </marker>
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
        var svg = """
        <g class="cluster" id="\(id)">
          <rect x="\(x)" y="\(y + 20)" width="\(w)" height="\(max(0, h - 20))" rx="2" ry="2" fill="\(clusterBkg)" stroke="\(clusterBorder)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
          <text x="\(node.x)" y="\(y + 12)" text-anchor="middle" font-family="\(fontFamily)" font-size="14" font-weight="bold" fill="\(textColor)">\(node.label.escapedXML)</text>
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

    let shape = blockNodeShapeName(node.type)
    let rx = node.rx ?? 0
    let ry = node.ry ?? 0
    let roundStr = rx > 0 ? " rx=\"\(rx)\" ry=\"\(ry)\"" : ""

    var svg = """
    <g class="node \(fullClassList)" id="\(id)">
    """

    switch shape {
    case "rect":
        svg += """
          <rect x="\(x)" y="\(y)" width="\(w)" height="\(h)"\(roundStr) fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
        """
    case "circle":
        let r = min(w, h) / 2
        svg += """
          <circle cx="\(node.x)" cy="\(node.y)" r="\(r)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
        """
    case "doublecircle":
        let outerR = min(w, h) / 2
        let innerR = outerR * 0.8
        svg += """
          <circle cx="\(node.x)" cy="\(node.y)" r="\(outerR)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
          <circle cx="\(node.x)" cy="\(node.y)" r="\(innerR)" fill="none" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
        """
    case "diamond":
        let mx = node.x; let my = node.y
        let hw = w / 2; let hh = h / 2
        svg += """
          <polygon points="\(mx),\(my - hh) \(mx + hw),\(my) \(mx),\(my + hh) \(mx - hw),\(my)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
        """
    case "hexagon":
        let mx = node.x; let my = node.y
        let hw = w / 2; let hh = h / 2
        let qw = w / 4
        svg += """
          <polygon points="\(mx - qw),\(my - hh) \(mx + qw),\(my - hh) \(mx + hw),\(my) \(mx + qw),\(my + hh) \(mx - qw),\(my + hh) \(mx - hw),\(my)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
        """
    case "stadium":
        let rx_s = min(w, h) / 2
        svg += """
          <rect x="\(x)" y="\(y)" width="\(w)" height="\(h)" rx="\(rx_s)" ry="\(rx_s)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
        """
    case "subroutine":
        let inset = w * 0.1
        svg += """
          <rect x="\(x + inset)" y="\(y)" width="\(max(0, w - 2 * inset))" height="\(h)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
          <rect x="\(x)" y="\(y)" width="\(inset + 3)" height="\(h)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
          <rect x="\(x + w - inset - 3)" y="\(y)" width="\(inset + 3)" height="\(h)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
        """
    case "cylinder":
        let arcH = h * 0.15
        svg += """
          <path d="M \(x),\(y + arcH) L \(x),\(y + h - arcH) A \(w/2),\(arcH) 0 0,0 \(x + w),\(y + h - arcH) L \(x + w),\(y + arcH) A \(w/2),\(arcH) 0 0,1 \(x),\(y + arcH)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
          <path d="M \(x),\(y + arcH) A \(w/2),\(arcH) 0 0,1 \(x + w),\(y + arcH)" fill="none" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
        """
    case "lean_right":
        let skew = w * 0.15
        svg += """
          <polygon points="\(x + skew),\(y) \(x + w),\(y) \(x + w - skew),\(y + h) \(x),\(y + h)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
        """
    case "lean_left":
        let skew = w * 0.15
        svg += """
          <polygon points="\(x),\(y) \(x + w - skew),\(y) \(x + w),\(y + h) \(x + skew),\(y + h)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
        """
    case "trapezoid":
        let skew = w * 0.15
        svg += """
          <polygon points="\(x + skew),\(y) \(x + w),\(y) \(x + w),\(y + h) \(x),\(y + h)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
        """
    case "inv_trapezoid":
        let skew = w * 0.15
        svg += """
          <polygon points="\(x),\(y) \(x + w),\(y) \(x + w - skew),\(y + h) \(x + skew),\(y + h)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
        """
    case "rect_left_inv_arrow":
        let mx = node.x; let my = node.y
        let hw = w / 2; let hh = h / 2
        svg += """
          <polygon points="\(mx - hw),\(my - hh) \(mx + hw),\(my - hh) \(mx + hw),\(my + hh) \(mx - hw),\(my + hh) \(mx - hw * 1.5),\(my)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
        """
    default:
        svg += """
          <rect x="\(x)" y="\(y)" width="\(w)" height="\(h)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(BlockRenderConstants.strokeWidth)"/>
        """
    }

    svg += renderBlockLabelSvg(label: node.label, x: node.x, y: node.y, color: textColor, fontFamily: fontFamily)
    svg += "</g>"
    return svg
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
        let labelWidth = max(40.0, Double(label.count) * 8.0)
        let labelBg = colors.surface ?? colors.bg
        svg += """
      <g class="edgeLabel">
        <rect x="\(pts[1].x - labelWidth / 2)" y="\(pts[1].y - 12)" width="\(labelWidth)" height="20" rx="\(BlockRenderConstants.edgeLabelCornerRadius)" fill="\(labelBg)" opacity="0.5" stroke="none"/>
        <text x="\(pts[1].x)" y="\(pts[1].y + 3)" text-anchor="middle" font-family="\(fontFamily)" font-size="12" fill="\(colors.fg)">\(label.escapedXML)</text>
      </g>
      """
    }

    svg += "</g>"
    return svg
}

private func blockMarkerAttribute(name: String, arrowType: String, markerIds: BlockMarkerIds) -> String {
    switch arrowType {
    case "arrow_point":
        return " \(name)=\"url(#\(markerIds.point))\""
    case "arrow_circle":
        return " \(name)=\"url(#\(markerIds.circle))\""
    case "arrow_cross":
        return " \(name)=\"url(#\(markerIds.cross))\""
    default:
        return ""
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
