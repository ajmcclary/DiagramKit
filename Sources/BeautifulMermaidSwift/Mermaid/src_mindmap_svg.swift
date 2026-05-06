import Foundation

func renderMindmapSvg(
    _ positioned: PositionedMindmapDiagram,
    diagramId: String,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) -> String {
    let svgId = "mindmap-\(diagramId)"
    var parts: [String] = []
    let w = max(1, positioned.width)
    let h = max(1, positioned.height)

    parts.append("<svg id=\"\(svgId)\" class=\"mindmapDiagram\" width=\"\(Int(w))\" height=\"\(Int(h))\" viewBox=\"0 0 \(Int(w)) \(Int(h))\" xmlns=\"http://www.w3.org/2000/svg\">")

    if let accTitle = positioned.accTitle {
        parts.append("<title>\(_svgEscape(accTitle))</title>")
    }
    if let accDescr = positioned.accDescr {
        parts.append("<desc>\(_svgEscape(accDescr))</desc>")
    }

    parts.append("<defs>")
    parts.append("<linearGradient id=\"\(svgId)-gradient\" x1=\"0%\" y1=\"0%\" x2=\"0%\" y2=\"100%\">")
    parts.append("<stop offset=\"0%\" stop-color=\"\(positioned.theme.gradientStart)\"/>")
    parts.append("<stop offset=\"100%\" stop-color=\"\(positioned.theme.gradientStop)\"/>")
    parts.append("</linearGradient>")

    if positioned.theme.dropShadow {
        parts.append("<filter id=\"\(svgId)-drop-shadow\" x=\"-50%\" y=\"-50%\" width=\"200%\" height=\"200%\">")
        parts.append("<feDropShadow dx=\"2\" dy=\"2\" stdDeviation=\"3\" flood-color=\"#00000033\"/>")
        parts.append("</filter>")
    }
    parts.append("</defs>")

    if !transparent && !(positioned.config.look.map({ $0 == "neo" }) ?? false) {
        parts.append("<rect width=\"100%\" height=\"100%\" fill=\"\(colors.bg)\"/>")
    }

    parts.append("<style>")
    parts.append(_generateMindmapCSS(theme: positioned.theme, svgId: svgId))
    parts.append("</style>")

    parts.append("<g class=\"mindmap\">")

    parts.append("<g class=\"edges\">")
    for edge in positioned.edges {
        if let path = edge.path {            parts.append("<path class=\"\(edge.edgeCssClass)\" d=\"\(path)\" fill=\"none\" stroke-width=\"\(_edgeStrokeWidth(edge: edge, config: positioned.config))\" stroke=\"\(_edgeColor(edge: edge, theme: positioned.theme))\" />")
        }
    }
    parts.append("</g>")

    parts.append("<g class=\"nodes\">")
    for node in positioned.nodes {
        let transform = "translate(\(Int(node.x - node.width / 2)),\(Int(node.y - node.height / 2)))"
        parts.append("<g class=\"\(_svgAttrEscape(node.fullCssClass))\" id=\"node_\(node.id)\" transform=\"\(transform)\">")
        parts.append(contentsOf: _drawMindmapNodeShape(node: node, theme: positioned.theme, config: positioned.config))
        parts.append(contentsOf: _drawMindmapNodeLabel(node: node, theme: positioned.theme, config: positioned.config))
        parts.append("</g>")
    }
    parts.append("</g>")

    parts.append("</g>")
    parts.append("</svg>")

    return parts.joined(separator: "\n")
}

private func _drawMindmapNodeShape(node: PositionedMindmapNode, theme: MindmapThemeConfig, config: MindmapConfig) -> [String] {
    let w = Int(node.width)
    let h = Int(node.height)
    let fill = _nodeFillColor(node: node, theme: theme, config: config)
    let stroke = _nodeStrokeColor(node: node, theme: theme, config: config)
    let strokeW = theme.strokeWidth
    let isNeo = config.look == "neo"
    let isRoot = node.isRoot

    switch node.type {
    case .default:
        if isNeo {
            return [
                "<path class=\"node-bkg node-no-border\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(strokeW)\" d=\"M0,10 Q0,0 10,0 L\(w - 10),0 Q\(w),0 \(w),10 L\(w),\(h) L0,\(h) Z\"/>",
            ]
        } else {
            let lineColor = node.section.map { theme.cScaleInv(for: $0) } ?? theme.cScaleInv0
            let lineClass = node.section.map { "node-line-\($0)" } ?? "node-line-0"
            var result: [String] = []
            if isRoot {                result.append("<rect class=\"node-bkg\" fill=\"\(fill)\" x=\"0\" y=\"0\" width=\"\(w)\" height=\"\(h)\" rx=\"5\" stroke=\"\(stroke)\" stroke-width=\"\(strokeW)\"/>")
            } else {
                result.append("<path class=\"node-bkg node-no-border\" fill=\"\(fill)\" d=\"M0,\(h) L0,10 Q0,0 10,0 L\(w - 10),0 Q\(w),0 \(w),10 L\(w),\(h) Z\"/>")
            }
            result.append("<line class=\"\(lineClass)\" x1=\"0\" y1=\"\(h)\" x2=\"\(w)\" y2=\"\(h)\" stroke=\"\(lineColor)\" stroke-width=\"2\"/>")
            return result
        }

    case .rect:
        if isNeo {
            return [
                "<rect class=\"node-bkg\" fill=\"\(fill)\" x=\"0\" y=\"0\" width=\"\(w)\" height=\"\(h)\" rx=\"5\" stroke=\"\(stroke)\" stroke-width=\"\(strokeW)\"/>"
            ]
        }
        return [
            "<rect class=\"node-bkg\" fill=\"\(fill)\" x=\"0\" y=\"0\" width=\"\(w)\" height=\"\(h)\" stroke=\"\(stroke)\" stroke-width=\"\(strokeW)\"/>"
        ]

    case .roundedRect:
        return [
            "<rect class=\"node-bkg\" fill=\"\(fill)\" x=\"0\" y=\"0\" width=\"\(w)\" height=\"\(h)\" rx=\"15\" ry=\"15\" stroke=\"\(stroke)\" stroke-width=\"\(strokeW)\"/>"
        ]

    case .circle:
        let r = w / 2
        let centerY = h / 2
        return [
            "<circle class=\"node-bkg\" fill=\"\(fill)\" cx=\"\(w / 2)\" cy=\"\(centerY)\" r=\"\(r)\" stroke=\"\(stroke)\" stroke-width=\"\(strokeW)\"/>"
        ]

    case .hexagon:
        let mh = Int(Double(h) / 4.0)
        return [
            "<polygon class=\"node-bkg\" fill=\"\(fill)\" points=\"\(mh),0 \(w - mh),0 \(w),\(h / 2) \(w - mh),\(h) \(mh),\(h) 0,\(h / 2)\" stroke=\"\(stroke)\" stroke-width=\"\(strokeW)\"/>"
        ]

    case .cloud:
        return [_cloudPath(w: w, h: h, fill: fill, stroke: stroke, strokeWidth: strokeW)]

    case .bang:
        return [_bangPath(w: w, h: h, fill: fill, stroke: stroke, strokeWidth: strokeW)]
    }
}

private func _cloudPath(w: Int, h: Int, fill: String, stroke: String, strokeWidth: Double) -> String {
    let cw = Double(w)
    let ch = Double(h)
    var d = "M\(cw * 0.3),\(ch * 0.7)"

    d += " C\(cw * 0.1),\(ch * 0.65) \(cw * 0.05),\(ch * 0.4) \(cw * 0.2),\(ch * 0.25)"
    d += " C\(cw * 0.05),\(ch * 0.05) \(cw * 0.35),\(ch * 0.0) \(cw * 0.5),\(ch * 0.15)"
    d += " C\(cw * 0.65),\(ch * 0.0) \(cw * 0.85),\(ch * 0.05) \(cw * 0.85),\(ch * 0.25)"
    d += " C\(cw * 0.95),\(ch * 0.35) \(cw * 0.9),\(ch * 0.55) \(cw * 0.75),\(ch * 0.65)"
    d += " C\(cw * 0.85),\(ch * 0.85) \(cw * 0.65),\(ch * 0.95) \(cw * 0.5),\(ch * 0.85)"
    d += " C\(cw * 0.35),\(ch * 0.95) \(cw * 0.15),\(ch * 0.85) \(cw * 0.3),\(ch * 0.7) Z"

    return "<path class=\"node-bkg cloud\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(strokeWidth)\" d=\"\(d)\"/>"
}

private func _bangPath(w: Int, h: Int, fill: String, stroke: String, strokeWidth: Double) -> String {
    let cw = Double(w)
    let ch = Double(h)
    let cx = cw / 2
    let cy = ch / 2
    let r = min(cw, ch) / 2

    var d = ""
    var first = true

    for i in 0..<5 {
        let angle = Double(i) * 2 * .pi / 5 - .pi / 2
        let nextAngle = angle + 2 * .pi / 5 - .pi / 2

        let x1 = cx + r * cos(angle)
        let y1 = cy + r * sin(angle)
        let x2 = cx + r * 0.55 * cos(angle + .pi / 10)
        let y2 = cy + r * 0.55 * sin(angle + .pi / 10)
        let x3 = cx + r * cos(nextAngle)
        let y3 = cy + r * sin(nextAngle)
        let x4 = cx + r * 0.55 * cos(nextAngle - .pi / 10)
        let y4 = cy + r * 0.55 * sin(nextAngle - .pi / 10)

        if first {
            d = "M\(x1),\(y1) C\(x2),\(y2) \(x4),\(y4) \(x3),\(y3)"
            first = false
        } else {
            d += " C\(x2),\(y2) \(x4),\(y4) \(x3),\(y3)"
        }
    }
    d += " Z"

    return "<path class=\"node-bkg bang\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(strokeWidth)\" d=\"\(d)\"/>"
}

private func _drawMindmapNodeLabel(node: PositionedMindmapNode, theme: MindmapThemeConfig, config: MindmapConfig) -> [String] {
    let w = Int(node.width)
    let h = Int(node.height)
    let fillColor = _labelFillColor(node: node, theme: theme, config: config)
    let fontSize = theme.fontSize
    let isCircle = node.type == .circle
    let hasIcon = node.icon != nil

    var result: [String] = []

    if hasIcon {
        let iconClass = "node-icon-\(node.section ?? 0)"
        result.append("<foreignObject x=\"5\" y=\"\(h / 2 - 20)\" width=\"40\" height=\"40\">")
        result.append("<div class=\"icon-container\"><i class=\"\(_svgAttrEscape(iconClass + " " + node.icon!))\"></i></div>")
        result.append("</foreignObject>")
    }

    let label = _normalizeMindmapLabelBreaks(node.descr)

    if label.contains("\n") {
        let lines = label.split(separator: "\n")
        let lineHeight = fontSize * 1.3
        let totalHeight = Double(lines.count) * lineHeight
        let startY = (Double(h) - totalHeight) / 2 + fontSize

        for (idx, line) in lines.enumerated() {
            let textX: Int
            if hasIcon && !isCircle {
                textX = w / 2 + 25
            } else {
                textX = w / 2
            }
            let textY = startY + Double(idx) * lineHeight
            result.append("<text class=\"mindmap-node-label\" x=\"\(textX)\" y=\"\(Int(textY))\" fill=\"\(fillColor)\" font-family=\"\(theme.fontFamily)\" font-size=\"\(Int(fontSize))\" text-anchor=\"middle\">\(_svgEscape(String(line)))</text>")
        }
    } else {
        let textX: Int
        if hasIcon && !isCircle {
            textX = w / 2 + 25
        } else {
            textX = w / 2
        }
        let textY = h / 2 + Int(fontSize) / 3
        result.append("<text class=\"mindmap-node-label\" x=\"\(textX)\" y=\"\(textY)\" fill=\"\(fillColor)\" font-family=\"\(theme.fontFamily)\" font-size=\"\(Int(fontSize))\" text-anchor=\"middle\" dominant-baseline=\"middle\">\(_svgEscape(label))</text>")
    }

    return result
}

private func _nodeFillColor(node: PositionedMindmapNode, theme: MindmapThemeConfig, config: MindmapConfig) -> String {
    if node.isRoot {
        return theme.git0
    }
    let section = node.section ?? 0
    return theme.cScale(for: section)
}

private func _nodeStrokeColor(node: PositionedMindmapNode, theme: MindmapThemeConfig, config: MindmapConfig) -> String {
    return theme.nodeBorder
}

private func _labelFillColor(node: PositionedMindmapNode, theme: MindmapThemeConfig, config: MindmapConfig) -> String {
    if node.isRoot {
        return theme.gitBranchLabel0
    }
    let section = node.section ?? 0
    return theme.cScaleLabel(for: section)
}

private func _edgeColor(edge: PositionedMindmapEdge, theme: MindmapThemeConfig) -> String {
    let section = edge.section ?? 0
    return theme.cScale(for: section)
}

private func _edgeStrokeWidth(edge: PositionedMindmapEdge, config: MindmapConfig) -> Double {
    let isNeo = config.look == "neo"
    let depth = edge.depth
    if isNeo {
        return max(10 - Double(depth - 1) * 2, 2)
    }
    return max(17 - 3 * Double(depth), 2)
}

private func _generateMindmapCSS(theme: MindmapThemeConfig, svgId: String) -> String {
    var css = """
    .mindmap-node { cursor: pointer; }
    .mindmap-node-label { font-family: \(theme.fontFamily); dominant-baseline: middle; }
    """

    for i in 0...11 {
        css += "\n.section-\(i) .mindmap-node-label { fill: \(theme.cScaleLabel(for: i)); }"
        css += "\n.section-edge-\(i) { stroke: \(theme.cScale(for: i)); }"
        css += "\n.node-line-\(i) { stroke: \(theme.cScaleInv(for: i)); }"
        css += "\n.node-icon-\(i) { color: \(theme.cScaleLabel(for: i)); }"
    }

    css += "\n.section-root .mindmap-node-label { fill: \(theme.gitBranchLabel0); }"
    css += "\n.section-root { fill: \(theme.git0); }"

    if theme.useGradient {
        css += "\n.edge { stroke: url(#\(svgId)-gradient); }"
    }

    return css
}

private func _svgEscape(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

private func _svgAttrEscape(_ text: String) -> String {
    _svgEscape(text).replacingOccurrences(of: "'", with: "&#39;")
}

private func _normalizeMindmapLabelBreaks(_ text: String) -> String {
    text.replacingOccurrences(
        of: "(?i)<br\\s*/?>",
        with: "\n",
        options: .regularExpression
    )
}
