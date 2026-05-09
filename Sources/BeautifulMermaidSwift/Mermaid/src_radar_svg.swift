import Foundation

public func renderRadarSvg(
    _ positioned: PositionedRadarDiagram,
    colors: DiagramColors,
    font: String = "Inter",
    transparent: Bool = false
) -> String {
    var parts: [String] = []

    let effectiveTheme = positioned.theme.withGlobalColors(fg: colors.fg, line: colors.line)

    parts.append(_radarSvgOpenTag(positioned, colors: colors, transparent: transparent, font: font))

    if let accTitle = positioned.accTitle {
        parts.append("<title>\(_escapeRadarXml(accTitle))</title>")
    }
    if let accDescr = positioned.accDescr {
        parts.append("<desc>\(_escapeRadarXml(accDescr))</desc>")
    }

    parts.append(_radarStyleBlock(effectiveTheme, includeLegend: positioned.showLegend))

    parts.append(#"<g transform="translate(\#(_rN(positioned.centerX)), \#(_rN(positioned.centerY)))">"#)

    if let title = positioned.title {
        parts.append(
            #"<text class="radarTitle" x="\#(_rN(title.x))" y="\#(_rN(title.y))" dominant-baseline="hanging" text-anchor="middle">\#(_escapeRadarXml(title.text))</text>"#
        )
    }

    for graticule in positioned.graticules {
        switch graticule.type {
        case .circle:
            if let r = graticule.radius {
                parts.append(#"<circle class="radarGraticule" r="\#(_rN(r))"/>"#)
            }
        case .polygon:
            if let pts = graticule.points {
                let pointsStr = pts.map { "\(_rN($0.x)),\(_rN($0.y))" }.joined(separator: " ")
                parts.append(#"<polygon class="radarGraticule" points="\#(pointsStr)"/>"#)
            }
        }
    }

    for line in positioned.axisLines {
        parts.append(
            #"<line class="radarAxisLine" x1="\#(_rN(line.x1))" y1="\#(_rN(line.y1))" x2="\#(_rN(line.x2))" y2="\#(_rN(line.y2))"/>"#
        )
    }

    for label in positioned.axisLabels {
        parts.append(
            #"<text class="radarAxisLabel" x="\#(_rN(label.x))" y="\#(_rN(label.y))" dominant-baseline="middle" text-anchor="middle">\#(_escapeRadarXml(label.text))</text>"#
        )
    }

    for curve in positioned.curves {
        switch curve.type {
        case .circle:
            let pathD = closedRoundCurveSVGPath(curve.points, tension: positioned.config.curveTension)
            parts.append(#"<path class="radarCurve-\#(curve.index)" d="\#(pathD)"/>"#)
        case .polygon:
            let pointsStr = curve.points.map { "\(_rN($0.x)),\(_rN($0.y))" }.joined(separator: " ")
            parts.append(#"<polygon class="radarCurve-\#(curve.index)" points="\#(pointsStr)"/>"#)
        }
    }

    if positioned.showLegend {
        for item in positioned.legendItems {
            parts.append(#"<g transform="translate(\#(_rN(item.x)), \#(_rN(item.y)))">"#)
            parts.append(#"<rect class="radarLegendBox-\#(item.index)" width="\#(_rN(item.boxSize))" height="\#(_rN(item.boxSize))"/>"#)
            parts.append(#"<text class="radarLegendText" x="16" y="0" dominant-baseline="hanging" text-anchor="start">\#(_escapeRadarXml(item.label))</text>"#)
            parts.append("</g>")
        }
    }

    parts.append("</g>")
    parts.append("</svg>")

    return parts.joined(separator: "\n")
}

// MARK: - Style block

private func _radarStyleBlock(_ theme: RadarThemeConfig, includeLegend: Bool) -> String {
    var css = "<style>\n"
    css += ".radarTitle { font-size: \(Int(theme.fontSize))px; color: \(theme.titleColor); dominant-baseline: hanging; text-anchor: middle; }\n"
    css += ".radarAxisLine { stroke: \(theme.axisColor); stroke-width: \(Int(theme.axisStrokeWidth)); }\n"
    css += ".radarAxisLabel { dominant-baseline: middle; text-anchor: middle; font-size: \(Int(theme.axisLabelFontSize))px; color: \(theme.axisColor); }\n"
    css += ".radarGraticule { fill: \(theme.graticuleColor); fill-opacity: \(_rN(theme.graticuleOpacity)); stroke: \(theme.graticuleColor); stroke-width: \(Int(theme.graticuleStrokeWidth)); }\n"
    if includeLegend {
        css += ".radarLegendText { text-anchor: start; font-size: \(Int(theme.legendFontSize))px; dominant-baseline: hanging; }\n"
    }

    for i in 0..<theme.themeColorLimit {
        let color = theme.curveColor(at: i)
        css += ".radarCurve-\(i) { color: \(color); fill: \(color); fill-opacity: \(_rN(theme.curveOpacity)); stroke: \(color); stroke-width: \(Int(theme.curveStrokeWidth)); }\n"
        if includeLegend {
            css += ".radarLegendBox-\(i) { fill: \(color); fill-opacity: \(_rN(theme.curveOpacity)); stroke: \(color); }\n"
        }
    }

    css += "</style>"
    return css
}

// MARK: - SVG open tag

private func _radarSvgOpenTag(
    _ positioned: PositionedRadarDiagram,
    colors: DiagramColors,
    transparent: Bool,
    font: String
) -> String {
    let w = _rN(positioned.width)
    let h = _rN(positioned.height)
    let bg = transparent ? "none" : colors.bg

    var attrs: [String] = [
        #"id="graphDiv""#,
        #"xmlns="http://www.w3.org/2000/svg""#,
        #"viewBox="0 0 \#(w) \#(h)""#,
        #"role="graphics-document document""#,
    ]

    var styles: [String] = []
    if positioned.config.useMaxWidth {
        attrs.append(#"width="100%""#)
        attrs.append(#"preserveAspectRatio="xMinYMin meet""#)
        styles.append("max-width: \(w)px")
    } else {
        attrs.append(#"width="\#(w)""#)
        attrs.append(#"height="\#(h)""#)
    }
    styles.append("background-color: \(bg)")
    styles.append("font-family: \(font)")
    attrs.append(#"style="\#(styles.joined(separator: "; "))""#)

    return "<svg \(attrs.joined(separator: " "))>"
}

// MARK: - XML escaping and number formatting

private func _escapeRadarXml(_ text: String) -> String {
    SVG.escapeAttribute(text)
}

private func _rN(_ n: Double) -> String {
    let rounded = (n * 10).rounded() / 10
    if rounded.isFinite && abs(rounded) < 1e15 && rounded == rounded.rounded() {
        return String(Int(rounded))
    }
    if !rounded.isFinite { return "0" }
    return String(format: "%.1f", rounded)
}
