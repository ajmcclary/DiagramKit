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

    parts.append("<g class=\"mindmap\"\(positioned.config.look == "neo" ? " data-look=\"neo\"" : "")>")

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
            let rd = 5
            let cw = Double(w)
            let ch = Double(h)
            let bottomLineY = ch - Double(rd)
            let pathD = "M0 \(bottomLineY) v\(-ch + 2 * Double(rd)) q0,-\(rd) \(rd),-\(rd) h\(cw - 2 * Double(rd)) q\(rd),0 \(rd),\(rd) v\(bottomLineY) H0 Z"
            result.append("<path class=\"node-bkg node-no-border\" fill=\"\(fill)\" d=\"\(pathD)\"/>")
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
    let r1 = 0.15 * cw
    let r2 = 0.25 * cw
    let r3 = 0.35 * cw
    let r4 = 0.20 * cw
    var d = "M0 0"
    d += " a\(_fmt(r1)),\(_fmt(r1)) 0 0,1 \(_fmt(cw * 0.25)),\(_fmt(-cw * 0.1))"
    d += " a\(_fmt(r3)),\(_fmt(r3)) 1 0,1 \(_fmt(cw * 0.4)),\(_fmt(-cw * 0.1))"
    d += " a\(_fmt(r2)),\(_fmt(r2)) 1 0,1 \(_fmt(cw * 0.35)),\(_fmt(cw * 0.2))"
    d += " a\(_fmt(r1)),\(_fmt(r1)) 1 0,1 \(_fmt(cw * 0.15)),\(_fmt(ch * 0.35))"
    d += " a\(_fmt(r4)),\(_fmt(r4)) 1 0,1 \(_fmt(-cw * 0.15)),\(_fmt(ch * 0.65))"
    d += " a\(_fmt(r2)),\(_fmt(r1)) 1 0,1 \(_fmt(-cw * 0.25)),\(_fmt(cw * 0.15))"
    d += " a\(_fmt(r3)),\(_fmt(r3)) 1 0,1 \(_fmt(-cw * 0.5)),0"
    d += " a\(_fmt(r1)),\(_fmt(r1)) 1 0,1 \(_fmt(-cw * 0.25)),\(_fmt(-cw * 0.15))"
    d += " a\(_fmt(r1)),\(_fmt(r1)) 1 0,1 \(_fmt(-cw * 0.1)),\(_fmt(-ch * 0.35))"
    d += " a\(_fmt(r4)),\(_fmt(r4)) 1 0,1 \(_fmt(cw * 0.1)),\(_fmt(-ch * 0.65))"
    d += " H0 V0 Z"
    return "<path class=\"node-bkg cloud\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(strokeWidth)\" d=\"\(d)\"/>"
}

private func _bangPath(w: Int, h: Int, fill: String, stroke: String, strokeWidth: Double) -> String {
    let cw = Double(w)
    let ch = Double(h)
    let r = 0.15 * cw
    let r08 = r * 0.8
    var d = "M0 0"
    d += " a\(_fmt(r)),\(_fmt(r)) 1 0,0 \(_fmt(cw * 0.25)),\(_fmt(-ch * 0.1))"
    d += " a\(_fmt(r)),\(_fmt(r)) 1 0,0 \(_fmt(cw * 0.25)),0"
    d += " a\(_fmt(r)),\(_fmt(r)) 1 0,0 \(_fmt(cw * 0.25)),0"
    d += " a\(_fmt(r)),\(_fmt(r)) 1 0,0 \(_fmt(cw * 0.25)),\(_fmt(ch * 0.1))"
    d += " a\(_fmt(r)),\(_fmt(r)) 1 0,0 \(_fmt(cw * 0.15)),\(_fmt(ch * 0.33))"
    d += " a\(_fmt(r08)),\(_fmt(r08)) 1 0,0 0,\(_fmt(ch * 0.34))"
    d += " a\(_fmt(r)),\(_fmt(r)) 1 0,0 \(_fmt(-cw * 0.15)),\(_fmt(ch * 0.33))"
    d += " a\(_fmt(r)),\(_fmt(r)) 1 0,0 \(_fmt(-cw * 0.25)),\(_fmt(ch * 0.15))"
    d += " a\(_fmt(r)),\(_fmt(r)) 1 0,0 \(_fmt(-cw * 0.25)),0"
    d += " a\(_fmt(r)),\(_fmt(r)) 1 0,0 \(_fmt(-cw * 0.25)),0"
    d += " a\(_fmt(r)),\(_fmt(r)) 1 0,0 \(_fmt(-cw * 0.25)),\(_fmt(-ch * 0.15))"
    d += " a\(_fmt(r)),\(_fmt(r)) 1 0,0 \(_fmt(-cw * 0.1)),\(_fmt(-ch * 0.33))"
    d += " a\(_fmt(r08)),\(_fmt(r08)) 1 0,0 0,\(_fmt(-ch * 0.34))"
    d += " a\(_fmt(r)),\(_fmt(r)) 1 0,0 \(_fmt(cw * 0.1)),\(_fmt(-ch * 0.33))"
    d += " H0 V0 Z"
    return "<path class=\"node-bkg bang\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(strokeWidth)\" d=\"\(d)\"/>"
}

private func _fmt(_ v: Double) -> String {
    let rounded = (v * 100).rounded() / 100
    let s = String(format: "%.2f", rounded)
    // Strip trailing zeros while preserving at least one decimal digit
    var result = s
    while result.hasSuffix("0") && result.contains(".") {
        let before = String(result.dropLast())
        if before.hasSuffix(".") { break }
        result = before
    }
    return result
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
        let section = node.section ?? 0
        let iconClass = "node-icon-\(section)"
        if isCircle {
            // Mermaid: foreignObject width=node.width height="50px" style="text-align:center;"
            // Icon placed at top, text below
            let foW = Int(node.width)
            result.append("<foreignObject x=\"0\" y=\"0\" width=\"\(foW)\" height=\"50\" style=\"text-align: center;\">")
            result.append("<div class=\"icon-container\"><i class=\"\(_svgAttrEscape(iconClass + " " + node.icon!))\"></i></div>")
            result.append("</foreignObject>")
        } else {
            // Mermaid: foreignObject width="60px" height=node.height with margin-top
            let orgHeight = Int(node.height)
            let foW = 60
            result.append("<foreignObject x=\"0\" y=\"0\" width=\"\(foW)\" height=\"\(orgHeight)\" style=\"text-align: center;\">")
            result.append("<div class=\"icon-container\"><i class=\"\(_svgAttrEscape(iconClass + " " + node.icon!))\"></i></div>")
            result.append("</foreignObject>")
        }
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
            result.append(_renderMarkdownTextSVG(
                String(line), x: textX, y: Int(textY), fill: fillColor, fontFamily: theme.fontFamily, fontSize: Int(fontSize)
            ))
        }
    } else {
        let textX: Int
        if hasIcon && !isCircle {
            textX = w / 2 + 25
        } else {
            textX = w / 2
        }
        let textY = h / 2 + Int(fontSize) / 3
        result.append(_renderMarkdownTextSVG(
            label, x: textX, y: textY, fill: fillColor, fontFamily: theme.fontFamily, fontSize: Int(fontSize), dominantBaseline: true
        ))
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
    .edge { fill: none; }
    .mindmap-node-label { font-family: \(theme.fontFamily); dominant-baseline: middle; }
    .icon-container { height: 100%; display: flex; justify-content: center; align-items: center; }
    """

    for i in 0..<12 {
        let si = i - 1
        let sectionLabel = si >= 0 ? ".section-\(si)" : ".section-root"
        let idx = min(max(i, 0), 11)
        let labelColor = theme.cScaleLabel(for: idx)
        let scaleColor = theme.cScale(for: idx)
        let invColor = theme.cScaleInv(for: idx)

        css += "\n\(sectionLabel) .mindmap-node-label { fill: \(labelColor); }"
        css += "\n.section-edge-\(si) { stroke: \(scaleColor); }"
        css += "\n.node-line-\(si) { stroke: \(invColor); }"
        css += "\n.node-icon-\(si) { font-size: 40px; color: \(labelColor); }"
    }

    css += "\n.section-root .mindmap-node-label { fill: \(theme.gitBranchLabel0); }"
    css += "\n.section-root rect, .section-root path, .section-root circle, .section-root polygon { fill: \(theme.git0); }"

    if theme.dropShadow {
        css += "\n[data-look=\"neo\"] .mindmap-node { filter: url(#\(svgId)-drop-shadow); }"
    }

    if theme.useGradient {
        css += "\n[data-look=\"neo\"] .mindmap-node rect, [data-look=\"neo\"] .mindmap-node path, " +
               "[data-look=\"neo\"] .mindmap-node circle, [data-look=\"neo\"] .mindmap-node polygon { " +
               "stroke: url(#\(svgId)-gradient); fill: \(theme.mainBkg); }"
        for i in 0..<12 {
            let si = i - 1
            css += "\n.section-\(si) line { stroke-width: 0; }"
        }
    }

    return css
}

private func _svgEscape(_ text: String) -> String {
    SVG.escapeText(text)
}

private func _svgAttrEscape(_ text: String) -> String {
    SVG.escapeAttribute(text)
}

private func _normalizeMindmapLabelBreaks(_ text: String) -> String {
    text.replacingOccurrences(
        of: "(?i)<br\\s*/?>",
        with: "\n",
        options: .regularExpression
    )
}

/// Splits text into segments of plain and formatted (bold/italic) spans.
struct _MarkdownSegment {
    let text: String
    let bold: Bool
    let italic: Bool
}

func _parseMarkdownSegments(_ text: String) -> [_MarkdownSegment] {
    var segments: [_MarkdownSegment] = []
    var remaining = text
    while !remaining.isEmpty {
        // Bold: **text**
        if let boldMatch = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*").firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)) {
            let preRange = remaining.startIndex..<Range(boldMatch.range(at: 0), in: remaining)!.lowerBound
            if preRange.lowerBound < preRange.upperBound {
                segments.append(_MarkdownSegment(text: String(remaining[preRange]), bold: false, italic: false))
            }
            let boldRange = Range(boldMatch.range(at: 1), in: remaining)!
            segments.append(_MarkdownSegment(text: String(remaining[boldRange]), bold: true, italic: false))
            remaining = String(remaining[Range(boldMatch.range(at: 0), in: remaining)!.upperBound...])
            continue
        }
        // Italic: *text* (but not **)
        if let italicMatch = try? NSRegularExpression(pattern: "(?<!\\*)\\*([^*]+)\\*(?!\\*)").firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)) {
            let preRange = remaining.startIndex..<Range(italicMatch.range(at: 0), in: remaining)!.lowerBound
            if preRange.lowerBound < preRange.upperBound {
                segments.append(_MarkdownSegment(text: String(remaining[preRange]), bold: false, italic: false))
            }
            let italicRange = Range(italicMatch.range(at: 1), in: remaining)!
            segments.append(_MarkdownSegment(text: String(remaining[italicRange]), bold: false, italic: true))
            remaining = String(remaining[Range(italicMatch.range(at: 0), in: remaining)!.upperBound...])
            continue
        }
        // Plain text remainder
        segments.append(_MarkdownSegment(text: remaining, bold: false, italic: false))
        break
    }
    return segments
}

private func _renderMarkdownTextSVG(_ text: String, x: Int, y: Int, fill: String, fontFamily: String, fontSize: Int, dominantBaseline: Bool = false) -> String {
    let segments = _parseMarkdownSegments(text)
    if segments.count == 1 && !segments[0].bold && !segments[0].italic {
        let db = dominantBaseline ? " dominant-baseline=\"middle\"" : ""
        return "<text class=\"mindmap-node-label\" x=\"\(x)\" y=\"\(y)\" fill=\"\(fill)\" font-family=\"\(fontFamily)\" font-size=\"\(fontSize)\" text-anchor=\"middle\"\(db)>\(_svgEscape(segments[0].text))</text>"
    }
    var parts = ["<text class=\"mindmap-node-label\" x=\"\(x)\" y=\"\(y)\" fill=\"\(fill)\" font-family=\"\(fontFamily)\" font-size=\"\(fontSize)\" text-anchor=\"middle\">"]
    for seg in segments {
        var attrs = ""
        let escaped = _svgEscape(seg.text)
        if seg.bold && seg.italic {
            attrs = " font-weight=\"bold\" font-style=\"italic\""
        } else if seg.bold {
            attrs = " font-weight=\"bold\""
        } else if seg.italic {
            attrs = " font-style=\"italic\""
        }
        parts.append("<tspan\(attrs)>\(escaped)</tspan>")
    }
    parts.append("</text>")
    return parts.joined()
}
