// Ported from original/src/renderer.ts
import Foundation

private struct _SvgPoint {
    var x: Double
    var y: Double
}

private struct _SvgNode {
    var id: String
    var label: String
    var descriptions: [String]
    var shape: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var inlineStyle: [String: String]
    var interaction: original_src_types.NodeInteraction?
    var icon: String?
    var img: String?
    var securityLevel: String?
}

private struct _SvgEdge {
    var source: String
    var target: String
    var label: String?
    var style: String
    var arrowHeadStart: ArrowHead
    var arrowHeadEnd: ArrowHead
    var points: [_SvgPoint]
    var labelPosition: _SvgPoint?
    var inlineStyle: [String: String]?
    var edgeId: String?
    var animate: Bool?
    var curve: String?
}

private struct _SvgGroup {
    var id: String
    var label: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var children: [_SvgGroup]
    var shape: String?
    var altBkg: Bool = false
}

private struct _SvgGraphModel {
    var width: Double
    var height: Double
    var nodes: [_SvgNode]
    var edges: [_SvgEdge]
    var groups: [_SvgGroup]
    var securityLevel: String?
    var isStateDiagram: Bool = false
}

public func renderSvg(
    _ graph: PositionedGraph,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false
) throws -> String {
    try _renderSvgEntry(graph, colors, font, transparent)
}

private func _renderSvgEntry(
    _ graph: PositionedGraph,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) throws -> String {
    let model = _extractSvgGraphModel(graph)
    var parts: [String] = []

    let themeColors = original_src_theme.DiagramColors(
        bg: colors.bg,
        fg: colors.fg,
        line: colors.line,
        accent: colors.accent,
        muted: colors.muted,
        surface: colors.surface,
        border: colors.border
    )

    parts.append(original_src_theme.svgOpenTag(model.width, model.height, themeColors, transparent))
    let accessibility = _graphAccessibility(graph.diagram)
    if let title = accessibility.title, !title.isEmpty {
        parts.append("<title>\(original_src_multiline_utils.escapeXml(title))</title>")
    }
    if let descr = accessibility.descr, !descr.isEmpty {
        parts.append("<desc>\(original_src_multiline_utils.escapeXml(descr))</desc>")
    }
    parts.append(original_src_theme.buildStyleBlock(font, false))
    parts.append("<defs>")
    parts.append(_arrowMarkerDefs())
    // Per-color arrow markers for edges with custom stroke via linkStyle
    var customStrokeColors = Set<String>()
    for edge in model.edges {
        if let stroke = edge.inlineStyle?["stroke"] {
            customStrokeColors.insert(stroke)
        }
    }
    for color in customStrokeColors {
        parts.append(_arrowMarkerDefsForColor(color))
    }
    parts.append("</defs>")

    // Edge animation CSS (Mermaid parity: animated edges use stroke-dashoffset)
    var styleParts: [String] = []
    styleParts.append(".edge-animated {")
    styleParts.append("  animation: edge-dash 1.5s linear infinite;")
    styleParts.append("  stroke-dasharray: 8 4;")
    styleParts.append("}")
    styleParts.append("@keyframes edge-dash {")
    styleParts.append("  to { stroke-dashoffset: -24; }")
    styleParts.append("}")
    if model.isStateDiagram {
        styleParts.append(".statediagram-state rect {")
        styleParts.append("  fill: var(--_node-fill);")
        styleParts.append("  stroke: var(--_node-stroke);")
        styleParts.append("}")
        styleParts.append(".statediagram-cluster rect {")
        styleParts.append("  fill: var(--_group-fill);")
        styleParts.append("  stroke: var(--_node-stroke);")
        styleParts.append("}")
        styleParts.append(".statediagram-cluster rect.outer {")
        styleParts.append("  rx: 5px;")
        styleParts.append("  ry: 5px;")
        styleParts.append("}")
        styleParts.append(".statediagram-cluster.statediagram-cluster-alt rect {")
        styleParts.append("  fill: var(--_surface);")
        styleParts.append("}")
        styleParts.append(".statediagram-note rect {")
        styleParts.append("  fill: var(--_note-bkg);")
        styleParts.append("  stroke: var(--_note-border);")
        styleParts.append("  stroke-width: 1px;")
        styleParts.append("  rx: 6;")
        styleParts.append("  ry: 6;")
        styleParts.append("}")
        styleParts.append(".statediagram-note text {")
        styleParts.append("  fill: var(--_text);")
        styleParts.append("}")
        styleParts.append(".note-edge {")
        styleParts.append("  stroke-dasharray: 5;")
        styleParts.append("}")
        styleParts.append(".transition {")
        styleParts.append("  stroke: var(--_line);")
        styleParts.append("}")
        styleParts.append("[data-look=\"neo\"].statediagram-cluster rect {")
        styleParts.append("  rx: 12px;")
        styleParts.append("  ry: 12px;")
        styleParts.append("}")
    }
    parts.append("<style>\n" + styleParts.joined(separator: "\n") + "\n</style>")

    for group in model.groups {
        parts.append(_renderGroup(group, font))
    }

    for edge in model.edges {
        parts.append(_renderEdge(edge, isStateDiagram: model.isStateDiagram))
    }

    for edge in model.edges where edge.label != nil {
        parts.append(_renderEdgeLabel(edge, font))
    }

    for node in model.nodes {
        parts.append(_renderNode(node, font, isStateDiagram: model.isStateDiagram))
    }

    parts.append("</svg>")
    return parts.joined(separator: "\n")
}

private func _arrowMarkerDefs() -> String {
    let w = original_src_styles.ARROW_HEAD.width
    let h = original_src_styles.ARROW_HEAD.height
    let arrowStyle = "fill=\"var(--_arrow)\" stroke=\"var(--_arrow)\" stroke-width=\"0.75\" stroke-linejoin=\"round\""
    let refX = w - 1
    var parts: [String] = []
    // Standard arrow
    parts.append("  <marker id=\"arrowhead\" markerWidth=\"\(w)\" markerHeight=\"\(h)\" refX=\"\(refX)\" refY=\"\(h / 2)\" orient=\"auto\">")
    parts.append("    <polygon points=\"0 0, \(w) \(h / 2), 0 \(h)\" \(arrowStyle) />")
    parts.append("  </marker>")
    parts.append("  <marker id=\"arrowhead-start\" markerWidth=\"\(w)\" markerHeight=\"\(h)\" refX=\"1\" refY=\"\(h / 2)\" orient=\"auto-start-reverse\">")
    parts.append("    <polygon points=\"\(w) 0, 0 \(h / 2), \(w) \(h)\" \(arrowStyle) />")
    parts.append("  </marker>")
    // Circle
    let cs: Double = h * 0.7
    parts.append("  <marker id=\"circlehead\" markerWidth=\"\(cs + 2)\" markerHeight=\"\(cs)\" refX=\"\(cs / 2 + 1)\" refY=\"\(cs / 2)\" orient=\"auto\">")
    parts.append("    <circle cx=\"\(cs / 2)\" cy=\"\(cs / 2)\" r=\"\(cs / 2 - 0.5)\" \(arrowStyle) />")
    parts.append("  </marker>")
    parts.append("  <marker id=\"circlehead-start\" markerWidth=\"\(cs + 2)\" markerHeight=\"\(cs)\" refX=\"\(cs / 2 - 1)\" refY=\"\(cs / 2)\" orient=\"auto-start-reverse\">")
    parts.append("    <circle cx=\"\(cs / 2)\" cy=\"\(cs / 2)\" r=\"\(cs / 2 - 0.5)\" \(arrowStyle) />")
    parts.append("  </marker>")
    // Cross
    let xs: Double = h * 0.6
    parts.append("  <marker id=\"crosshead\" markerWidth=\"\(xs)\" markerHeight=\"\(xs)\" refX=\"\(xs / 2)\" refY=\"\(xs / 2)\" orient=\"auto\">")
    parts.append("    <line x1=\"0\" y1=\"0\" x2=\"\(xs)\" y2=\"\(xs)\" stroke=\"var(--_arrow)\" stroke-width=\"1.5\" />")
    parts.append("    <line x1=\"\(xs)\" y1=\"0\" x2=\"0\" y2=\"\(xs)\" stroke=\"var(--_arrow)\" stroke-width=\"1.5\" />")
    parts.append("  </marker>")
    parts.append("  <marker id=\"crosshead-start\" markerWidth=\"\(xs)\" markerHeight=\"\(xs)\" refX=\"\(xs / 2)\" refY=\"\(xs / 2)\" orient=\"auto-start-reverse\">")
    parts.append("    <line x1=\"0\" y1=\"0\" x2=\"\(xs)\" y2=\"\(xs)\" stroke=\"var(--_arrow)\" stroke-width=\"1.5\" />")
    parts.append("    <line x1=\"\(xs)\" y1=\"0\" x2=\"0\" y2=\"\(xs)\" stroke=\"var(--_arrow)\" stroke-width=\"1.5\" />")
    parts.append("  </marker>")
    // Diamond
    parts.append("  <marker id=\"diamondhead\" markerWidth=\"\(w * 1.2)\" markerHeight=\"\(h)\" refX=\"\(w)\" refY=\"\(h / 2)\" orient=\"auto\">")
    parts.append("    <polygon points=\"0 \(h / 2), \(w * 0.6) 0, \(w * 1.2) \(h / 2), \(w * 0.6) \(h)\" \(arrowStyle) />")
    parts.append("  </marker>")
    parts.append("  <marker id=\"diamondhead-start\" markerWidth=\"\(w * 1.2)\" markerHeight=\"\(h)\" refX=\"\(w * 0.2)\" refY=\"\(h / 2)\" orient=\"auto-start-reverse\">")
    parts.append("    <polygon points=\"\(w * 0.6) \(h / 2), 0 0, \(w * 1.2) \(h / 2), 0 \(h)\" \(arrowStyle) />")
    parts.append("  </marker>")
    return parts.joined(separator: "\n")
}

private func _arrowMarkerDefsForColor(_ color: String) -> String {
    let w = original_src_styles.ARROW_HEAD.width
    let h = original_src_styles.ARROW_HEAD.height
    let escaped = _escapeAttr(color)
    let arrowStyle = "fill=\"\(escaped)\" stroke=\"\(escaped)\" stroke-width=\"0.75\" stroke-linejoin=\"round\""
    let refX = w - 1
    let suffix = _markerSuffix(color)
    var parts: [String] = []
    // Arrow
    parts.append("  <marker id=\"arrowhead-\(suffix)\" markerWidth=\"\(w)\" markerHeight=\"\(h)\" refX=\"\(refX)\" refY=\"\(h / 2)\" orient=\"auto\">")
    parts.append("    <polygon points=\"0 0, \(w) \(h / 2), 0 \(h)\" \(arrowStyle) />")
    parts.append("  </marker>")
    parts.append("  <marker id=\"arrowhead-start-\(suffix)\" markerWidth=\"\(w)\" markerHeight=\"\(h)\" refX=\"1\" refY=\"\(h / 2)\" orient=\"auto-start-reverse\">")
    parts.append("    <polygon points=\"\(w) 0, 0 \(h / 2), \(w) \(h)\" \(arrowStyle) />")
    parts.append("  </marker>")
    // Circle
    let cs: Double = h * 0.7
    parts.append("  <marker id=\"circlehead-\(suffix)\" markerWidth=\"\(cs + 2)\" markerHeight=\"\(cs)\" refX=\"\(cs / 2 + 1)\" refY=\"\(cs / 2)\" orient=\"auto\">")
    parts.append("    <circle cx=\"\(cs / 2)\" cy=\"\(cs / 2)\" r=\"\(cs / 2 - 0.5)\" fill=\"\(escaped)\" stroke=\"\(escaped)\" stroke-width=\"0.75\" />")
    parts.append("  </marker>")
    parts.append("  <marker id=\"circlehead-start-\(suffix)\" markerWidth=\"\(cs + 2)\" markerHeight=\"\(cs)\" refX=\"\(cs / 2 - 1)\" refY=\"\(cs / 2)\" orient=\"auto-start-reverse\">")
    parts.append("    <circle cx=\"\(cs / 2)\" cy=\"\(cs / 2)\" r=\"\(cs / 2 - 0.5)\" fill=\"\(escaped)\" stroke=\"\(escaped)\" stroke-width=\"0.75\" />")
    parts.append("  </marker>")
    // Cross
    let xs: Double = h * 0.6
    parts.append("  <marker id=\"crosshead-\(suffix)\" markerWidth=\"\(xs)\" markerHeight=\"\(xs)\" refX=\"\(xs / 2)\" refY=\"\(xs / 2)\" orient=\"auto\">")
    parts.append("    <line x1=\"0\" y1=\"0\" x2=\"\(xs)\" y2=\"\(xs)\" stroke=\"\(escaped)\" stroke-width=\"1.5\" />")
    parts.append("    <line x1=\"\(xs)\" y1=\"0\" x2=\"0\" y2=\"\(xs)\" stroke=\"\(escaped)\" stroke-width=\"1.5\" />")
    parts.append("  </marker>")
    parts.append("  <marker id=\"crosshead-start-\(suffix)\" markerWidth=\"\(xs)\" markerHeight=\"\(xs)\" refX=\"\(xs / 2)\" refY=\"\(xs / 2)\" orient=\"auto-start-reverse\">")
    parts.append("    <line x1=\"0\" y1=\"0\" x2=\"\(xs)\" y2=\"\(xs)\" stroke=\"\(escaped)\" stroke-width=\"1.5\" />")
    parts.append("    <line x1=\"\(xs)\" y1=\"0\" x2=\"0\" y2=\"\(xs)\" stroke=\"\(escaped)\" stroke-width=\"1.5\" />")
    parts.append("  </marker>")
    // Diamond
    parts.append("  <marker id=\"diamondhead-\(suffix)\" markerWidth=\"\(w * 1.2)\" markerHeight=\"\(h)\" refX=\"\(w)\" refY=\"\(h / 2)\" orient=\"auto\">")
    parts.append("    <polygon points=\"0 \(h / 2), \(w * 0.6) 0, \(w * 1.2) \(h / 2), \(w * 0.6) \(h)\" \(arrowStyle) />")
    parts.append("  </marker>")
    parts.append("  <marker id=\"diamondhead-start-\(suffix)\" markerWidth=\"\(w * 1.2)\" markerHeight=\"\(h)\" refX=\"\(w * 0.2)\" refY=\"\(h / 2)\" orient=\"auto-start-reverse\">")
    parts.append("    <polygon points=\"\(w * 0.6) \(h / 2), 0 0, \(w * 1.2) \(h / 2), 0 \(h)\" \(arrowStyle) />")
    parts.append("  </marker>")
    return parts.joined(separator: "\n")
}

private func _markerSuffix(_ color: String) -> String {
    color.unicodeScalars.map { scalar in
        let ch = Character(scalar)
        if ch.isLetter || ch.isNumber { return String(ch) }
        return String(scalar.value, radix: 16)
    }.joined()
}

private func _renderGroup(_ group: _SvgGroup, _ font: String) -> String {
    _ = font
    let isStateComposite = group.shape == "rounded-with-title"
    let clusterClass = isStateComposite
        ? (group.altBkg ? "statediagram-cluster statediagram-cluster-alt" : "statediagram-cluster")
        : "subgraph"
    var parts: [String] = []

    if isStateComposite {
        parts.append("<g class=\"\(clusterClass)\" data-id=\"\(_escapeAttr(group.id))\" data-label=\"\(_escapeAttr(group.label))\">")
        let titleH: Double = 35
        let fill = "var(--_group-fill)"
        let stroke = "var(--_node-stroke)"
        let sw = "\(original_src_styles.STROKE_WIDTHS.outerBox)"
        parts.append("  <rect x=\"\(group.x)\" y=\"\(group.y)\" width=\"\(group.width)\" height=\"\(group.height)\" rx=\"8\" ry=\"8\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />")
        parts.append("  <rect x=\"\(group.x)\" y=\"\(group.y)\" width=\"\(group.width)\" height=\"\(titleH)\" rx=\"8\" ry=\"8\" fill=\"var(--_surface)\" stroke=\"none\" />")
        parts.append("  <rect x=\"\(group.x)\" y=\"\(group.y + titleH - 8)\" width=\"\(group.width)\" height=\"8\" fill=\"var(--_surface)\" stroke=\"none\" />")
        let titleText = original_src_multiline_utils.renderMultilineText(
            group.label,
            cx: group.x + group.width / 2,
            cy: group.y + titleH / 2,
            fontSize: original_src_styles.FONT_SIZES.groupHeader,
            attrs: "text-anchor=\"middle\" font-size=\"\(original_src_styles.FONT_SIZES.groupHeader)\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.groupHeader)\" fill=\"var(--_text-sec)\""
        )
        parts.append("  \(titleText)")
    } else {
        let headerHeight = original_src_styles.FONT_SIZES.groupHeader + 16
        parts.append("<g class=\"subgraph\" data-id=\"\(_escapeAttr(group.id))\" data-label=\"\(_escapeAttr(group.label))\">")
        parts.append(
            "  <rect x=\"\(group.x)\" y=\"\(group.y)\" width=\"\(group.width)\" height=\"\(group.height)\" " +
                "rx=\"0\" ry=\"0\" fill=\"var(--_group-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />"
        )
        parts.append(
            "  <rect x=\"\(group.x)\" y=\"\(group.y)\" width=\"\(group.width)\" height=\"\(headerHeight)\" " +
                "rx=\"0\" ry=\"0\" fill=\"var(--_group-hdr)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />"
        )
        let header = original_src_multiline_utils.renderMultilineText(
            group.label,
            cx: group.x + 12,
            cy: group.y + headerHeight / 2,
            fontSize: original_src_styles.FONT_SIZES.groupHeader,
            attrs: "font-size=\"\(original_src_styles.FONT_SIZES.groupHeader)\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.groupHeader)\" fill=\"var(--_text-sec)\""
        )
        parts.append("  \(header)")
    }

    for child in group.children {
        parts.append(_renderGroup(child, font))
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

private func _renderEdge(_ edge: _SvgEdge, isStateDiagram: Bool = false) -> String {
    if edge.points.count < 2 {
        return ""
    }

    // Invisible edges don't render stroke
    let isInvisible = edge.style == "invisible" || edge.inlineStyle?["stroke"] == "none"

    let dashArray = edge.style == "dotted" ? " stroke-dasharray=\"4 4\"" : ""
    let baseStrokeWidth = edge.style == "thick"
        ? original_src_styles.STROKE_WIDTHS.connector * 2
        : original_src_styles.STROKE_WIDTHS.connector
    let strokeColor = isInvisible ? "none" : _escapeAttr(edge.inlineStyle?["stroke"] ?? "var(--_line)")
    let strokeWidth = isInvisible ? "0" : _escapeAttr(edge.inlineStyle?["stroke-width"] ?? "\(baseStrokeWidth)")

    // Compute edge CSS class
    var edgeClass = "edge"
    if edge.animate == true { edgeClass += " edge-animated" }
    if isStateDiagram {
        edgeClass += " transition"
        if edge.style == "dotted" {
            edgeClass += " note-edge"
        }
    }

    // Use curved path when curve interpolation is specified
    let curveType = edge.curve ?? ""
    let useCurvedPath = !curveType.isEmpty && curveType != "linear"
    let pathElement: String
    if useCurvedPath {
        let d = _curvePathData(points: edge.points, curveType: curveType)
        pathElement = "path"
        let dataAttrs = _edgeDataAttrs(edge)
        return "<\(pathElement) \(dataAttrs) class=\"\(edgeClass)\" d=\"\(d)\" fill=\"none\" stroke=\"\(strokeColor)\" " +
            "stroke-width=\"\(strokeWidth)\"\(dashArray)\(_edgeMarkers(edge, isInvisible: isInvisible)) />"
    } else {
        let pathData = _pointsToPolylinePath(edge.points)
        pathElement = "polyline"
        let dataAttrs = _edgeDataAttrs(edge)
        let pointsAttr = "points=\"\(pathData)\""
        return "<\(pathElement) \(dataAttrs) class=\"\(edgeClass)\" \(pointsAttr) fill=\"none\" stroke=\"\(strokeColor)\" " +
            "stroke-width=\"\(strokeWidth)\"\(dashArray)\(_edgeMarkers(edge, isInvisible: isInvisible)) />"
    }
}

private func _edgeDataAttrs(_ edge: _SvgEdge) -> String {
    var dataAttrs: [String] = [
        "data-from=\"\(_escapeAttr(edge.source))\"",
        "data-to=\"\(_escapeAttr(edge.target))\"",
        "data-style=\"\(_escapeAttr(edge.style))\"",
        "data-arrow-start=\"\(edge.arrowHeadStart != .none)\"",
        "data-arrow-end=\"\(edge.arrowHeadEnd != .none)\"",
    ]
    if let label = edge.label {
        dataAttrs.append("data-label=\"\(_escapeAttr(label))\"")
    }
    if let edgeId = edge.edgeId {
        dataAttrs.append("data-edge-id=\"\(_escapeAttr(edgeId))\"")
    }
    if let curve = edge.curve {
        dataAttrs.append("data-curve=\"\(_escapeAttr(curve))\"")
    }
    if edge.animate == true {
        dataAttrs.append("data-animate=\"true\"")
    }
    return dataAttrs.joined(separator: " ")
}

private func _edgeMarkers(_ edge: _SvgEdge, isInvisible: Bool) -> String {
    func markerId(_ arrowHead: ArrowHead, isStart: Bool) -> String? {
        let suffix: String
        if let strokeColor = edge.inlineStyle?["stroke"], !isInvisible {
            suffix = "-\(_markerSuffix(strokeColor))"
        } else {
            suffix = ""
        }
        switch arrowHead {
        case .none: return nil
        case .arrow, .open:
            return isStart ? "arrowhead-start\(suffix)" : "arrowhead\(suffix)"
        case .circle:
            return isStart ? "circlehead-start\(suffix)" : "circlehead\(suffix)"
        case .cross:
            return isStart ? "crosshead-start\(suffix)" : "crosshead\(suffix)"
        case .diamond:
            return isStart ? "diamondhead-start\(suffix)" : "diamondhead\(suffix)"
        }
    }

    var markers = ""
    if let mid = markerId(edge.arrowHeadEnd, isStart: false) {
        markers += " marker-end=\"url(#\(mid))\""
    }
    if let mid = markerId(edge.arrowHeadStart, isStart: true) {
        markers += " marker-start=\"url(#\(mid))\""
    }
    return markers
}

private func _curvePathData(points: [_SvgPoint], curveType: String) -> String {
    guard points.count >= 2 else { return "" }
    var parts: [String] = []
    parts.append("M\(points[0].x),\(points[0].y)")

    if curveType == "step" || curveType == "stepBefore" {
        for i in 1..<points.count {
            parts.append("V\(points[i].y)")
            parts.append("H\(points[i].x)")
        }
    } else if curveType == "stepAfter" {
        for i in 1..<points.count {
            parts.append("H\(points[i].x)")
            parts.append("V\(points[i].y)")
        }
    } else if curveType == "basis" || curveType == "natural" {
        // Catmull-Rom to cubic Bezier conversion for smooth curves
        let pts = points
        let n = pts.count - 1
        for i in 0..<n {
            let p0 = pts[max(0, i - 1)]
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = pts[min(pts.count - 1, i + 2)]
            let tension: Double = curveType == "basis" ? 1.0 / 6.0 : 1.0 / 2.0
            let cp1x = p1.x + (p2.x - p0.x) * tension
            let cp1y = p1.y + (p2.y - p0.y) * tension
            let cp2x = p2.x - (p3.x - p1.x) * tension
            let cp2y = p2.y - (p3.y - p1.y) * tension
            parts.append("C\(cp1x),\(cp1y) \(cp2x),\(cp2y) \(p2.x),\(p2.y)")
        }
    } else {
        // Default to linear
        for i in 1..<points.count {
            parts.append("L\(points[i].x),\(points[i].y)")
        }
    }
    return parts.joined(separator: " ")
}

private func _pointsToPolylinePath(_ points: [_SvgPoint]) -> String {
    points.map { "\($0.x),\($0.y)" }.joined(separator: " ")
}

private func _renderEdgeLabel(_ edge: _SvgEdge, _ font: String) -> String {
    _ = font
    let mid = edge.labelPosition ?? _edgeMidpoint(edge.points)
    let label = edge.label ?? ""
    let padding = 8.0
    let metrics = original_src_text_metrics.measureMultilineText(
        label,
        fontSize: original_src_styles.FONT_SIZES.edgeLabel,
        fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
    )

    let content = original_src_multiline_utils.renderMultilineTextWithBackground(
        label,
        cx: mid.x,
        cy: mid.y,
        textWidth: metrics.width,
        textHeight: metrics.height,
        fontSize: original_src_styles.FONT_SIZES.edgeLabel,
        padding: padding,
        textAttrs: "text-anchor=\"middle\" font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-sec)\"",
        bgAttrs: "rx=\"2\" ry=\"2\" fill=\"var(--bg)\" stroke=\"var(--_inner-stroke)\" stroke-width=\"1\""
    )

    return "<g class=\"edge-label\" data-from=\"\(_escapeAttr(edge.source))\" data-to=\"\(_escapeAttr(edge.target))\" data-label=\"\(_escapeAttr(label))\">\n" +
        "  \(content.replacingOccurrences(of: "\n", with: "\n  "))\n" +
        "</g>"
}

private func _edgeMidpoint(_ points: [_SvgPoint]) -> _SvgPoint {
    if points.isEmpty {
        return _SvgPoint(x: 0, y: 0)
    }
    if points.count == 1 {
        return points[0]
    }

    var totalLength = 0.0
    for i in 1 ..< points.count {
        totalLength += _dist(points[i - 1], points[i])
    }

    var remaining = totalLength / 2
    for i in 1 ..< points.count {
        let segLen = _dist(points[i - 1], points[i])
        if remaining <= segLen {
            let t = segLen == 0 ? 0 : (remaining / segLen)
            return _SvgPoint(
                x: points[i - 1].x + t * (points[i].x - points[i - 1].x),
                y: points[i - 1].y + t * (points[i].y - points[i - 1].y)
            )
        }
        remaining -= segLen
    }

    return points[points.count - 1]
}

private func _dist(_ a: _SvgPoint, _ b: _SvgPoint) -> Double {
    let dx = b.x - a.x
    let dy = b.y - a.y
    return (dx * dx + dy * dy).squareRoot()
}

private func _renderNode(_ node: _SvgNode, _ font: String, isStateDiagram: Bool = false) -> String {
    let shape = _renderNodeShape(node)
    let label = _renderNodeLabel(node, font)

    var nodeClass = "node"
    if isStateDiagram {
        if node.shape == "state-note" {
            nodeClass += " statediagram-note"
        } else if node.shape != "text", node.shape != "invisible" {
            nodeClass += " statediagram-state"
        }
    }

    var parts: [String] = []
    parts.append("<g class=\"\(nodeClass)\" data-id=\"\(_escapeAttr(node.id))\" data-label=\"\(_escapeAttr(node.label))\" data-shape=\"\(_escapeAttr(node.shape))\">")
    parts.append("  \(shape.replacingOccurrences(of: "\n", with: "\n  "))")
    if !label.isEmpty {
        parts.append("  \(label.replacingOccurrences(of: "\n", with: "\n  "))")
    }
    parts.append("</g>")
    let group = parts.joined(separator: "\n")
    guard let anchorAttributes = _nodeAnchorAttributes(node) else {
        return group
    }
    return "<a \(anchorAttributes)>\n" +
        "  \(group.replacingOccurrences(of: "\n", with: "\n  "))\n" +
        "</a>"
}

private func _nodeAnchorAttributes(_ node: _SvgNode) -> String? {
    if let sl = node.securityLevel, sl.lowercased() == "sandbox" { return nil }
    guard let interaction = node.interaction else { return nil }
    let url: String
    switch interaction.type {
    case .href(let href):
        url = href
    default:
        return nil
    }
    let target = (interaction.target?.isEmpty == false) ? interaction.target! : "_blank"
    var attrs = [
        #"xlink:href="\#(_escapeAttr(url))""#,
        #"target="\#(_escapeAttr(target))""#,
    ]
    if let tooltip = interaction.tooltip, !tooltip.isEmpty {
        attrs.append(#"title="\#(_escapeAttr(tooltip))""#)
    }
    return attrs.joined(separator: " ")
}

private func _renderNodeShape(_ node: _SvgNode) -> String {
    let x = node.x
    let y = node.y
    let width = node.width
    let height = node.height
    let shape = node.shape
    let inlineStyle = node.inlineStyle

    let fill = _escapeAttr(inlineStyle["fill"] ?? "var(--_node-fill)")
    let stroke = _escapeAttr(inlineStyle["stroke"] ?? "var(--_node-stroke)")
    let sw = _escapeAttr(inlineStyle["stroke-width"] ?? "\(original_src_styles.STROKE_WIDTHS.innerBox)")

    switch shape {
    case "diamond":
        return _renderDiamond(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "rounded":
        return _renderRoundedRect(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "stadium":
        return _renderStadium(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "circle":
        return _renderCircle(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "subroutine":
        return _renderSubroutine(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "doublecircle":
        return _renderDoubleCircle(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "hexagon":
        return _renderHexagon(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "cylinder":
        return _renderCylinder(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "asymmetric":
        return _renderAsymmetric(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "trapezoid":
        return _renderTrapezoid(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "trapezoid-alt":
        return _renderTrapezoidAlt(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "state-start":
        return _renderStateStart(x: x, y: y, w: width, h: height)
    case "state-end":
        return _renderStateEnd(x: x, y: y, w: width, h: height)
    case "ellipse":
        return _renderCircle(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "parallelogram":
        return _renderParallel(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "parallelogram-alt":
        return _renderParallelAlt(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "triangle":
        return _renderTriangle(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "bang":
        return _renderBang(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "small-circle", "filled-circle":
        return _renderFilledCircle(x: x, y: y, w: width, h: height)
    case "framed-circle":
        return _renderFramedCircle(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "fork", "join":
        return _renderForkJoinBar(x: x, y: y, w: width, h: height)
    case "text", "invisible":
        return _renderRect(x: x, y: y, w: width, h: height, fill: "none", stroke: "none", sw: "1")
    case "crossed-circle":
        return _renderCrossedCircle(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "document":
        return _renderDocument(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "divided-rectangle":
        return _renderDividedRect(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "window-pane":
        return _renderWindowPane(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "lightning-bolt":
        return _renderLightningBolt(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "bow-tie-rectangle":
        return _renderBowTie(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "flag":
        return _renderFlag(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "cloud":
        return _renderCloud(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "curved-trapezoid":
        return _renderCurvedTrapezoid(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "delay":
        return _renderDelay(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "notched-rectangle":
        return _renderNotchedRect(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "notched-pentagon":
        return _renderTriangle(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "tagged-document":
        return _renderTaggedDocument(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "tagged-rectangle":
        return _renderTaggedRect(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "stacked-document":
        return _renderStackedDocument(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "stacked-rectangle":
        return _renderStackedRect(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "lined-rectangle", "lined-process":
        return _renderLinedRect(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "lined-document":
        return _renderLinedDocument(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "lined-cylinder", "disk":
        return _renderLinedCylinder(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "horizontal-cylinder", "h-cyl", "das":
        return _renderHorizontalCylinder(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "data-store", "datastore":
        return _renderDataStore(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "flipped-triangle":
        return _renderFlippedTriangle(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "sloped-rectangle":
        return _renderSlopedRect(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "brace-l":
        return _renderBraceL(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "brace-r":
        return _renderBraceR(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "braces":
        return _renderBraces(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "icon-square":
        return _renderIconSquare(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw, icon: node.icon, img: node.img)
    case "icon-circle":
        return _renderIconCircle(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw, icon: node.icon, img: node.img)
    case "icon":
        return _renderIconDefault(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw, icon: node.icon, img: node.img)
    case "icon-rounded":
        return _renderIconRounded(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw, icon: node.icon, img: node.img)
    case "image-square":
        return _renderImageRect(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw, img: node.img)
    case "state", "note":
        return _renderRect(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "choice":
        return _renderDiamond(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "rect-with-title":
        return _renderRectWithTitle(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "rounded-with-title":
        return _renderRoundedWithTitle(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
    case "state-divider":
        return _renderStateDivider(x: x, y: y, w: width, h: height, stroke: stroke)
    case "state-note":
        let noteFill = _escapeAttr(inlineStyle["fill"] ?? "var(--_note-bkg)")
        let noteStroke = _escapeAttr(inlineStyle["stroke"] ?? "var(--_note-border)")
        return _renderRoundedRect(x: x, y: y, w: width, h: height, fill: noteFill, stroke: noteStroke, sw: sw)
    case "label-rect", "anchor": break
    default: break
    }
    return _renderRect(x: x, y: y, w: width, h: height, fill: fill, stroke: stroke, sw: sw)
}

private func _renderRect(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"0\" ry=\"0\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderRoundedRect(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"6\" ry=\"6\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderStadium(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let r = h / 2
    return "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"\(r)\" ry=\"\(r)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderCircle(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let cx = x + w / 2
    let cy = y + h / 2
    let r = min(w, h) / 2
    return "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(r)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderDiamond(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let cx = x + w / 2
    let cy = y + h / 2
    let hw = w / 2
    let hh = h / 2
    let points = [
        "\(cx),\(cy - hh)",
        "\(cx + hw),\(cy)",
        "\(cx),\(cy + hh)",
        "\(cx - hw),\(cy)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderSubroutine(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let inset = 8.0
    return "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"0\" ry=\"0\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<line x1=\"\(x + inset)\" y1=\"\(y)\" x2=\"\(x + inset)\" y2=\"\(y + h)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<line x1=\"\(x + w - inset)\" y1=\"\(y)\" x2=\"\(x + w - inset)\" y2=\"\(y + h)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderDoubleCircle(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let cx = x + w / 2
    let cy = y + h / 2
    let outerR = min(w, h) / 2
    let innerR = outerR - 5
    return "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(outerR)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(innerR)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderHexagon(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let inset = h / 4
    let points = [
        "\(x + inset),\(y)",
        "\(x + w - inset),\(y)",
        "\(x + w),\(y + h / 2)",
        "\(x + w - inset),\(y + h)",
        "\(x + inset),\(y + h)",
        "\(x),\(y + h / 2)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderCylinder(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let ry = 7.0
    let cx = x + w / 2
    let bodyTop = y + ry
    let bodyH = h - 2 * ry
    return "<rect x=\"\(x)\" y=\"\(bodyTop)\" width=\"\(w)\" height=\"\(bodyH)\" fill=\"\(fill)\" stroke=\"none\" />\n" +
        "<line x1=\"\(x)\" y1=\"\(bodyTop)\" x2=\"\(x)\" y2=\"\(bodyTop + bodyH)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<line x1=\"\(x + w)\" y1=\"\(bodyTop)\" x2=\"\(x + w)\" y2=\"\(bodyTop + bodyH)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<ellipse cx=\"\(cx)\" cy=\"\(y + h - ry)\" rx=\"\(w / 2)\" ry=\"\(ry)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<ellipse cx=\"\(cx)\" cy=\"\(bodyTop)\" rx=\"\(w / 2)\" ry=\"\(ry)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderAsymmetric(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let indent = 12.0
    let points = [
        "\(x + indent),\(y)",
        "\(x + w),\(y)",
        "\(x + w),\(y + h)",
        "\(x + indent),\(y + h)",
        "\(x),\(y + h / 2)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderTrapezoid(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let inset = w * 0.15
    let points = [
        "\(x + inset),\(y)",
        "\(x + w - inset),\(y)",
        "\(x + w),\(y + h)",
        "\(x),\(y + h)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderTrapezoidAlt(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let inset = w * 0.15
    let points = [
        "\(x),\(y)",
        "\(x + w),\(y)",
        "\(x + w - inset),\(y + h)",
        "\(x + inset),\(y + h)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderStateStart(x: Double, y: Double, w: Double, h: Double) -> String {
    let cx = x + w / 2
    let cy = y + h / 2
    let r = min(w, h) / 2 - 2
    return "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(r)\" fill=\"var(--_text)\" stroke=\"none\" />"
}

private func _renderStateEnd(x: Double, y: Double, w: Double, h: Double) -> String {
    let cx = x + w / 2
    let cy = y + h / 2
    let outerR = min(w, h) / 2 - 2
    let innerR = outerR - 4
    return "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(outerR)\" fill=\"none\" stroke=\"var(--_text)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.innerBox * 2)\" />\n" +
        "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(innerR)\" fill=\"var(--_text)\" stroke=\"none\" />"
}

private func _renderRectWithTitle(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let titleH: Double = 24
    var parts: [String] = []
    parts.append("<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"4\" ry=\"4\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />")
    parts.append("<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(titleH)\" rx=\"4\" ry=\"4\" fill=\"var(--_surface)\" stroke=\"none\" />")
    parts.append("<line x1=\"\(x)\" y1=\"\(y + titleH)\" x2=\"\(x + w)\" y2=\"\(y + titleH)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />")
    return parts.joined(separator: "\n")
}

private func _renderRoundedWithTitle(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let titleH: Double = 35
    var parts: [String] = []
    parts.append("<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"8\" ry=\"8\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />")
    parts.append("<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(titleH)\" rx=\"8\" ry=\"8\" fill=\"var(--_surface)\" stroke=\"none\" />")
    parts.append("<rect x=\"\(x)\" y=\"\(y + titleH - 8)\" width=\"\(w)\" height=\"8\" fill=\"var(--_surface)\" stroke=\"none\" />")
    return parts.joined(separator: "\n")
}

private func _renderStateDivider(x: Double, y: Double, w: Double, h: Double, stroke: String) -> String {
    let cy = y + h / 2
    return "<line x1=\"\(x)\" y1=\"\(cy)\" x2=\"\(x + w)\" y2=\"\(cy)\" stroke=\"\(stroke)\" stroke-width=\"1\" stroke-dasharray=\"5,5\" opacity=\"0.6\" />"
}

private func _renderForkJoinBar(x: Double, y: Double, w: Double, h: Double) -> String {
    "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"2\" ry=\"2\" fill=\"var(--_text)\" stroke=\"none\" />"
}

private func _renderParallel(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let skew = w * 0.2
    let points = [
        "\(x + skew),\(y)",
        "\(x + w),\(y)",
        "\(x + w - skew),\(y + h)",
        "\(x),\(y + h)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderParallelAlt(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let skew = w * 0.2
    let points = [
        "\(x),\(y)",
        "\(x + w - skew),\(y)",
        "\(x + w),\(y + h)",
        "\(x + skew),\(y + h)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderTriangle(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let points = ["\(x + w / 2),\(y)", "\(x + w),\(y + h)", "\(x),\(y + h)"].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderBang(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let cx = x + w / 2, cy = y + h / 2, r = min(w, h) / 2
    return "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(r)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<line x1=\"\(cx)\" y1=\"\(y)\" x2=\"\(cx)\" y2=\"\(y + h)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderFilledCircle(x: Double, y: Double, w: Double, h: Double) -> String {
    let cx = x + w / 2, cy = y + h / 2, r = min(w, h) / 2 - 2
    return "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(r)\" fill=\"var(--_text)\" stroke=\"none\" />"
}

private func _renderFramedCircle(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let cx = x + w / 2, cy = y + h / 2
    let outerR = min(w, h) / 2
    let innerR = outerR - 4
    return "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(outerR)\" fill=\"none\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(innerR)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderCrossedCircle(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let cx = x + w / 2, cy = y + h / 2, r = min(w, h) / 2
    let hs = r * 0.5
    return "<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(r)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<line x1=\"\(cx - hs)\" y1=\"\(cy - hs)\" x2=\"\(cx + hs)\" y2=\"\(cy + hs)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<line x1=\"\(cx + hs)\" y1=\"\(cy - hs)\" x2=\"\(cx - hs)\" y2=\"\(cy + hs)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderDividedRect(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    return "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"0\" ry=\"0\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<line x1=\"\(x)\" y1=\"\(y + h / 2)\" x2=\"\(x + w)\" y2=\"\(y + h / 2)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderWindowPane(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let inset = w * 0.2
    return "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"0\" ry=\"0\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<rect x=\"\(x + w - inset - 4)\" y=\"\(y + 4)\" width=\"\(inset)\" height=\"\(h - 8)\" fill=\"none\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderDocument(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let waveDepth = h * 0.15
    let points = [
        "\(x),\(y)",
        "\(x + w),\(y)",
        "\(x + w),\(y + h - waveDepth)",
        "\(x + w * 0.8),\(y + h + waveDepth * 0.5)",
        "\(x + w * 0.6),\(y + h - waveDepth * 1.5)",
        "\(x + w * 0.4),\(y + h + waveDepth * 0.5)",
        "\(x + w * 0.2),\(y + h - waveDepth * 1.5)",
        "\(x),\(y + h - waveDepth)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderHourglass(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let midY = y + h / 2, pinch = w * 0.15
    let points = [
        "\(x),\(y)", "\(x + w),\(y)",
        "\(x + w / 2 + pinch),\(midY)",
        "\(x + w),\(y + h)", "\(x),\(y + h)",
        "\(x + w / 2 - pinch),\(midY)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderLightningBolt(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let points = [
        "\(x + w * 0.4),\(y)",
        "\(x + w * 0.25),\(y + h * 0.4)",
        "\(x + w * 0.55),\(y + h * 0.4)",
        "\(x + w * 0.35),\(y + h * 0.6)",
        "\(x + w * 0.75),\(y + h)",
        "\(x + w * 0.5),\(y + h * 0.6)",
        "\(x + w * 0.2),\(y + h * 0.6)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderBowTie(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let midX = x + w / 2, midY = y + h / 2
    let points = [
        "\(x),\(y)", "\(midX),\(midY)",
        "\(x + w),\(y)", "\(midX),\(midY)",
        "\(x + w),\(y + h)", "\(midX),\(midY)",
        "\(x),\(y + h)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderFlag(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let inset = w * 0.15
    let points = [
        "\(x),\(y)", "\(x + w - inset),\(y)",
        "\(x + w),\(y + h / 2)",
        "\(x + w - inset),\(y + h)",
        "\(x),\(y + h)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderCloud(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let r = min(w, h) * 0.12
    let midX = x + w / 2, midY = y + h / 2
    let path = "M\(midX),\(y + r * 0.5) " +
               "C\(midX + r * 2),\(y - r * 0.3) \(x + w),\(y - r * 0.2) \(x + w - r),\(y + r) " +
               "C\(x + w + r),\(y + r * 2) \(x + w + r),\(midY - r) \(x + w - r * 0.5),\(midY) " +
               "C\(x + w + r),\(midY + r) \(x + w + r),\(y + h - r) \(x + w - r),\(y + h - r) " +
               "C\(x + w - r * 2),\(y + h + r * 0.3) \(midX + r * 2),\(y + h + r * 0.5) \(midX),\(y + h) " +
               "C\(midX - r * 2),\(y + h + r * 0.5) \(x),\(y + h + r * 0.3) \(x + r),\(y + h - r) " +
               "C\(x - r),\(y + h - r * 2) \(x - r),\(midY + r) \(x + r * 0.5),\(midY) " +
               "C\(x - r),\(midY - r) \(x - r),\(y + r) \(x + r),\(y + r) " +
               "C\(x + r * 2),\(y - r * 0.3) \(midX - r),\(y - r) \(midX),\(y + r * 0.5) Z"
    return "<path d=\"\(path)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderCurvedTrapezoid(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let inset = w * 0.15, cp = h * 0.2
    return "<path d=\"M\(x + inset),\(y) Q\(x + w - inset),\(y) \(x + w),\(y + h - cp) L\(x + w),\(y + h) L\(x),\(y + h) Q\(x),\(y + h - cp) \(x + inset),\(y)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderDelay(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let r = h / 2
    return "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"\(r)\" ry=\"\(r)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderNotchedRect(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let n: Double = 10
    let points = [
        "\(x),\(y)",
        "\(x + w - n),\(y)",
        "\(x + w),\(y + n)",
        "\(x + w),\(y + h)",
        "\(x),\(y + h)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderTaggedDocument(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let waveDepth = h * 0.15, n: Double = 10
    let points = [
        "\(x),\(y)",
        "\(x + w - n),\(y)",
        "\(x + w - n),\(y + n)",
        "\(x + w),\(y + n)",
        "\(x + w),\(y + h - waveDepth)",
        "\(x + w * 0.8),\(y + h + waveDepth * 0.5)",
        "\(x + w * 0.6),\(y + h - waveDepth * 1.5)",
        "\(x + w * 0.4),\(y + h + waveDepth * 0.5)",
        "\(x + w * 0.2),\(y + h - waveDepth * 1.5)",
        "\(x),\(y + h - waveDepth)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />" +
        "<polygon points=\"\(x + w - n),\(y) \(x + w - n),\(y + n) \(x + w),\(y + n)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderTaggedRect(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let n: Double = 10
    return "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"0\" ry=\"0\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />" +
        "<polygon points=\"\(x + w - n),\(y) \(x + w - n),\(y + n) \(x + w),\(y + n)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderStackedDocument(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let off: Double = 4
    let front = _renderDocument(x: x, y: y, w: w, h: h, fill: fill, stroke: stroke, sw: sw)
    let waveDepth = h * 0.15
    let backPoints = [
        "\(x - off),\(y - off)",
        "\(x + w - off),\(y - off)",
        "\(x + w - off),\(y + h - waveDepth - off)",
        "\(x + w * 0.8 - off),\(y + h + waveDepth * 0.5 - off)",
        "\(x + w * 0.6 - off),\(y + h - waveDepth * 1.5 - off)",
        "\(x + w * 0.4 - off),\(y + h + waveDepth * 0.5 - off)",
        "\(x + w * 0.2 - off),\(y + h - waveDepth * 1.5 - off)",
        "\(x - off),\(y + h - waveDepth - off)",
    ].joined(separator: " ")
    return "<polygon points=\"\(backPoints)\" fill=\"none\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" opacity=\"0.4\" />\n" + front
}

private func _renderStackedRect(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let off: Double = 4
    return "<rect x=\"\(x - off)\" y=\"\(y - off)\" width=\"\(w)\" height=\"\(h)\" rx=\"0\" ry=\"0\" fill=\"none\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" opacity=\"0.4\" />\n" +
        "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"0\" ry=\"0\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderLinedRect(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    return "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" rx=\"0\" ry=\"0\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<line x1=\"\(x + 4)\" y1=\"\(y)\" x2=\"\(x + 4)\" y2=\"\(y + h)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" opacity=\"0.5\" />"
}

private func _renderLinedDocument(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let doc = _renderDocument(x: x, y: y, w: w, h: h, fill: fill, stroke: stroke, sw: sw)
    let ly = y + h * 0.3
    return doc + "\n<line x1=\"\(x + 8)\" y1=\"\(ly)\" x2=\"\(x + w - 8)\" y2=\"\(ly)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" opacity=\"0.4\" />" +
        "<line x1=\"\(x + 8)\" y1=\"\(ly + 6)\" x2=\"\(x + w - 16)\" y2=\"\(ly + 6)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" opacity=\"0.3\" />"
}

private func _renderLinedCylinder(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let cyl = _renderCylinder(x: x, y: y, w: w, h: h, fill: fill, stroke: stroke, sw: sw)
    let ly = y + h / 2
    return cyl + "\n<line x1=\"\(x)\" y1=\"\(ly)\" x2=\"\(x + w)\" y2=\"\(ly)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" stroke-dasharray=\"3 3\" opacity=\"0.5\" />"
}

private func _renderHorizontalCylinder(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let rx = 7.0  // ellipse radius on x-axis for horizontal
    let cx = x + w / 2
    return "<rect x=\"\(x + rx)\" y=\"\(y)\" width=\"\(w - 2 * rx)\" height=\"\(h)\" fill=\"\(fill)\" stroke=\"none\" />\n" +
        "<line x1=\"\(x + rx)\" y1=\"\(y)\" x2=\"\(x + w - rx)\" y2=\"\(y)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<line x1=\"\(x + rx)\" y1=\"\(y + h)\" x2=\"\(x + w - rx)\" y2=\"\(y + h)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<ellipse cx=\"\(cx)\" cy=\"\(y)\" rx=\"\(rx)\" ry=\"\(h / 2)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<ellipse cx=\"\(cx)\" cy=\"\(y + h)\" rx=\"\(rx)\" ry=\"\(h / 2)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderDataStore(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let ry = 10.0, cx = x + w / 2
    let bodyTop = y + ry, bodyH = h - 2 * ry
    return "<path d=\"M\(x),\(bodyTop) L\(x),\(bodyTop + bodyH) " +
           "A\(w / 2),\(ry) 0 0,0 \(x + w),\(bodyTop + bodyH) " +
           "L\(x + w),\(bodyTop) A\(w / 2),\(ry) 0 0,1 \(x),\(bodyTop) Z\" " +
           "fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />\n" +
        "<ellipse cx=\"\(cx)\" cy=\"\(bodyTop)\" rx=\"\(w / 2)\" ry=\"\(ry)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderFlippedTriangle(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let points = ["\(x),\(y)", "\(x + w),\(y + h / 2)", "\(x),\(y + h)"].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderSlopedRect(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let slope = w * 0.15
    let points = [
        "\(x + slope),\(y)",
        "\(x + w),\(y)",
        "\(x + w),\(y + h)",
        "\(x),\(y + h)",
    ].joined(separator: " ")
    return "<polygon points=\"\(points)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
}

private func _renderBraceL(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let midY = y + h / 2
    let points = [
        "\(x + w * 0.4),\(y + 2)",
        "\(x + 2),\(y + h * 0.1)",
        "\(x + w * 0.3),\(midY)",
        "\(x + 2),\(y + h * 0.9)",
        "\(x + w * 0.4),\(y + h - 2)",
    ].joined(separator: " ")
    return "<polyline points=\"\(points)\" fill=\"none\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" stroke-linejoin=\"round\" />"
}

private func _renderBraceR(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    let midY = y + h / 2
    let points = [
        "\(x + w * 0.6),\(y + 2)",
        "\(x + w - 2),\(y + h * 0.1)",
        "\(x + w * 0.7),\(midY)",
        "\(x + w - 2),\(y + h * 0.9)",
        "\(x + w * 0.6),\(y + h - 2)",
    ].joined(separator: " ")
    return "<polyline points=\"\(points)\" fill=\"none\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" stroke-linejoin=\"round\" />"
}

private func _renderBraces(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String) -> String {
    return _renderBraceL(x: x, y: y, w: w, h: h, fill: fill, stroke: stroke, sw: sw) + "\n" +
        _renderBraceR(x: x, y: y, w: w, h: h, fill: fill, stroke: stroke, sw: sw)
}

// MARK: - Icon and image node rendering

private func _renderIconContent(icon: String?, img: String?, x: Double, y: Double, w: Double, h: Double) -> String {
    if let imageUrl = img, !imageUrl.isEmpty {
        let lowered = imageUrl.lowercased().trimmingCharacters(in: .whitespaces)
        let dangerous = ["javascript:", "data:", "vbscript:", "file:"]
        let isSafe = !dangerous.contains(where: { lowered.hasPrefix($0) })
        if isSafe {
            let pad: Double = 4
            return "<image x=\"\(x + pad)\" y=\"\(y + pad)\" width=\"\(w - pad * 2)\" height=\"\(h - pad * 2)\" xlink:href=\"\(_escapeAttr(imageUrl))\" preserveAspectRatio=\"xMidYMid meet\" />"
        }
    }
    if let iconName = icon, !iconName.isEmpty {
        let trimmed = iconName.hasPrefix("fa:") ? String(iconName.dropFirst(3)) : iconName
        let fontSize = min(w, h) * 0.5
        return "<text x=\"\(x + w / 2)\" y=\"\(y + h / 2)\" text-anchor=\"middle\" dominant-baseline=\"central\" font-size=\"\(fontSize)\" fill=\"currentColor\" class=\"icon-label\">\(original_src_multiline_utils.escapeXml(trimmed))</text>"
    }
    return ""
}

private func _renderIconSquare(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String, icon: String?, img: String?) -> String {
    let rect = _renderRect(x: x, y: y, w: w, h: h, fill: fill, stroke: stroke, sw: sw)
    let content = _renderIconContent(icon: icon, img: img, x: x, y: y, w: w, h: h)
    return content.isEmpty ? rect : "\(rect)\n\(content)"
}

private func _renderIconCircle(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String, icon: String?, img: String?) -> String {
    let circle = _renderCircle(x: x, y: y, w: w, h: h, fill: fill, stroke: stroke, sw: sw)
    let content = _renderIconContent(icon: icon, img: img, x: x, y: y, w: w, h: h)
    return content.isEmpty ? circle : "\(circle)\n\(content)"
}

private func _renderIconDefault(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String, icon: String?, img: String?) -> String {
    let rect = _renderRect(x: x, y: y, w: w, h: h, fill: fill, stroke: stroke, sw: sw)
    let content = _renderIconContent(icon: icon, img: img, x: x, y: y, w: w, h: h)
    return content.isEmpty ? rect : "\(rect)\n\(content)"
}

private func _renderIconRounded(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String, icon: String?, img: String?) -> String {
    let rect = _renderRoundedRect(x: x, y: y, w: w, h: h, fill: fill, stroke: stroke, sw: sw)
    let content = _renderIconContent(icon: icon, img: img, x: x, y: y, w: w, h: h)
    return content.isEmpty ? rect : "\(rect)\n\(content)"
}

private func _renderImageRect(x: Double, y: Double, w: Double, h: Double, fill: String, stroke: String, sw: String, img: String?) -> String {
    let rect = _renderRect(x: x, y: y, w: w, h: h, fill: fill, stroke: stroke, sw: sw)
    let content = _renderIconContent(icon: nil, img: img, x: x, y: y, w: w, h: h)
    return content.isEmpty ? rect : "\(rect)\n\(content)"
}

private func _renderNodeLabel(_ node: _SvgNode, _ font: String) -> String {
    _ = font
    if (node.shape == "state-start" || node.shape == "state-end" || node.shape == "fork" || node.shape == "join"), node.label.isEmpty {
        return ""
    }

    let cx = node.x + node.width / 2
    let cy = node.y + node.height / 2
    let textColor = _escapeAttr(node.inlineStyle["color"] ?? "var(--_text)")

    if node.shape == "rect-with-title", node.descriptions.count > 1 {
        let titleY = node.y + 12
        let bodyY = node.y + 24 + (node.height - 24) / 2
        let title = original_src_multiline_utils.renderMultilineText(
            node.descriptions[0],
            cx: cx,
            cy: titleY,
            fontSize: original_src_styles.FONT_SIZES.nodeLabel,
            attrs: "text-anchor=\"middle\" font-size=\"\(original_src_styles.FONT_SIZES.nodeLabel)\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.nodeLabel)\" fill=\"\(textColor)\""
        )
        let body = original_src_multiline_utils.renderMultilineText(
            node.descriptions.dropFirst().joined(separator: "\n"),
            cx: cx,
            cy: bodyY,
            fontSize: original_src_styles.FONT_SIZES.nodeLabel,
            attrs: "text-anchor=\"middle\" font-size=\"\(original_src_styles.FONT_SIZES.nodeLabel)\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.nodeLabel)\" fill=\"\(textColor)\""
        )
        return title + "\n" + body
    }

    return original_src_multiline_utils.renderMultilineText(
        node.label,
        cx: cx,
        cy: cy,
        fontSize: original_src_styles.FONT_SIZES.nodeLabel,
        attrs: "text-anchor=\"middle\" font-size=\"\(original_src_styles.FONT_SIZES.nodeLabel)\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.nodeLabel)\" fill=\"\(textColor)\""
    )
}

private func _escapeAttr(_ value: String) -> String {
    SVG.escapeAttribute(value)
}

private func _extractSvgGraphModel(_ graph: PositionedGraph) -> _SvgGraphModel {
    let secLevel = _graphSecurityLevel(graph.diagram)
    let isState: Bool
    switch graph.diagram.payload {
    case .stateDiagram: isState = true
    default: isState = false
    }
    return _SvgGraphModel(
        width: graph.width,
        height: graph.height,
        nodes: (graph.flowchartNodes ?? []).map { $0 as Any }.map { _extractNode($0, securityLevel: secLevel) },
        edges: (graph.flowchartEdges ?? []).map { $0 as Any }.map(_extractEdge),
        groups: (graph.flowchartGroups ?? []).map { $0 as Any }.map(_extractGroup),
        securityLevel: secLevel,
        isStateDiagram: isState
    )
}

private func _extractNode(_ any: Any, securityLevel: String? = nil) -> _SvgNode {
    let props = _readNodeProperties(any, label: "properties")
    return _SvgNode(
        id: _readString(any, label: "id") ?? "",
        label: _readString(any, label: "label") ?? "",
        descriptions: _readStringArray(any, label: "descriptions"),
        shape: _readString(any, label: "shape") ?? "rectangle",
        x: _readDouble(any, label: "x") ?? 0,
        y: _readDouble(any, label: "y") ?? 0,
        width: _readDouble(any, label: "width") ?? 0,
        height: _readDouble(any, label: "height") ?? 0,
        inlineStyle: _readStringMap(any, label: "inlineStyle") ?? [:],
        interaction: _readNodeInteraction(any, label: "interaction"),
        icon: props?.icon,
        img: props?.img,
        securityLevel: securityLevel
    )
}

private func _extractEdge(_ any: Any) -> _SvgEdge {
    _SvgEdge(
        source: _readString(any, label: "source") ?? "",
        target: _readString(any, label: "target") ?? "",
        label: _readOptionalString(any, label: "label"),
        style: _readString(any, label: "style") ?? "solid",
        arrowHeadStart: _readArrowHead(any, label: "arrowHeadStart") ?? .none,
        arrowHeadEnd: _readArrowHead(any, label: "arrowHeadEnd") ?? .arrow,
        points: _readArray(any, label: "points").map(_extractPoint),
        labelPosition: _readAny(any, label: "labelPosition").map(_extractPoint),
        inlineStyle: _readStringMap(any, label: "inlineStyle"),
        edgeId: _readOptionalString(any, label: "edgeId"),
        animate: _readBool(any, label: "animate"),
        curve: _readOptionalString(any, label: "curve")
    )
}

private func _readArrowHead(_ any: Any, label: String) -> ArrowHead? {
    guard let value = _readAny(any, label: label) else { return nil }
    if let str = value as? String {
        return ArrowHead(rawValue: str)
    }
    // Mirror gives back the enum case directly; String(describing:) yields the raw value
    return ArrowHead(rawValue: String(describing: value))
}

private func _extractGroup(_ any: Any) -> _SvgGroup {
    _SvgGroup(
        id: _readString(any, label: "id") ?? "",
        label: _readString(any, label: "label") ?? "",
        x: _readDouble(any, label: "x") ?? 0,
        y: _readDouble(any, label: "y") ?? 0,
        width: _readDouble(any, label: "width") ?? 0,
        height: _readDouble(any, label: "height") ?? 0,
        children: _readArray(any, label: "children").map(_extractGroup),
        shape: _readOptionalString(any, label: "shape"),
        altBkg: _readBool(any, label: "altBkg") ?? false
    )
}

private func _extractPoint(_ any: Any) -> _SvgPoint {
    _SvgPoint(
        x: _readDouble(any, label: "x") ?? 0,
        y: _readDouble(any, label: "y") ?? 0
    )
}

private func _unboxOptional(_ any: Any) -> Any? {
    let mirror = Mirror(reflecting: any)
    guard mirror.displayStyle == .optional else {
        return any
    }
    return mirror.children.first?.value
}

private func _readAny(_ any: Any, label: String) -> Any? {
    for child in Mirror(reflecting: any).children where child.label == label {
        return _unboxOptional(child.value)
    }
    return nil
}

private func _readArray(_ any: Any, label: String) -> [Any] {
    guard let value = _readAny(any, label: label) else {
        return []
    }
    return value as? [Any] ?? []
}

private func _readString(_ any: Any, label: String) -> String? {
    guard let value = _readAny(any, label: label) else {
        return nil
    }
    if let text = value as? String {
        return text
    }
    return String(describing: value)
}

private func _readOptionalString(_ any: Any, label: String) -> String? {
    guard let value = _readAny(any, label: label) else {
        return nil
    }
    return value as? String
}

private func _readDouble(_ any: Any, label: String) -> Double? {
    guard let value = _readAny(any, label: label) else {
        return nil
    }
    if let number = value as? Double {
        return number
    }
    if let number = value as? Int {
        return Double(number)
    }
    if let number = value as? Float {
        return Double(number)
    }
    if let number = value as? NSNumber {
        return number.doubleValue
    }
    return nil
}

private func _readBool(_ any: Any, label: String) -> Bool? {
    guard let value = _readAny(any, label: label) else {
        return nil
    }
    if let b = value as? Bool {
        return b
    }
    if let n = value as? NSNumber {
        return n.boolValue
    }
    return nil
}

private func _readStringMap(_ any: Any, label: String) -> [String: String]? {
    guard let value = _readAny(any, label: label) else {
        return nil
    }
    return value as? [String: String]
}

private func _readStringArray(_ any: Any, label: String) -> [String] {
    guard let value = _readAny(any, label: label) else {
        return []
    }
    return value as? [String] ?? []
}

private func _readNodeProperties(_ any: Any, label: String) -> original_src_types.NodeProperties? {
    _readAny(any, label: label) as? original_src_types.NodeProperties
}

private func _readNodeInteraction(_ any: Any, label: String) -> original_src_types.NodeInteraction? {
    _readAny(any, label: label) as? original_src_types.NodeInteraction
}

private func _graphAccessibility(_ graph: MermaidGraph) -> (title: String?, descr: String?) {
    switch graph.payload {
    case .flowchart(let parsed), .stateDiagram(let parsed):
        return (parsed.accTitle, parsed.accDescr)
    default:
        return (nil, nil)
    }
}

private func _graphSecurityLevel(_ graph: MermaidGraph) -> String? {
    switch graph.payload {
    case .flowchart(let parsed):
        return parsed.config?.securityLevel
    case .stateDiagram(let parsed):
        return parsed.stateConfig.securityLevel
    default:
        return nil
    }
}

open class original_src_renderer {
    public init() {}

    // Export inventory from TypeScript source:
    // - export function renderSvg
    public static func renderSvg(
        _ graph: PositionedGraph,
        _ colors: DiagramColors,
        _ font: String = "Inter",
        _ transparent: Bool = false
    ) throws -> String {
        try _renderSvgEntry(graph, colors, font, transparent)
    }
}
