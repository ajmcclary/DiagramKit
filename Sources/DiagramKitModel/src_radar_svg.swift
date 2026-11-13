import Foundation
import DiagramKitCommon

public func renderRadarSvg(
    _ positioned: PositionedRadarDiagram,
    colors: DiagramColors,
    font: String = DiagramSVGFontFamily.proportional,
    transparent: Bool = false
) -> String {
    var parts: [String] = []

    let effectiveTheme = positioned.theme.withGlobalColors(fg: colors.fg, line: colors.line)

    parts.append(_radarSvgOpenTag(positioned, colors: colors, transparent: transparent, font: font))

    if let accTitle = positioned.accTitle {
        parts.append("<title>\(SVG.escapeText(accTitle))</title>")
    }
    if let accDescr = positioned.accDescr {
        parts.append("<desc>\(SVG.escapeText(accDescr))</desc>")
    }

    parts.append(_radarStyleBlock(effectiveTheme, includeLegend: positioned.showLegend))

    parts.append(#"<g transform="translate(\#(_rN(positioned.centerX)), \#(_rN(positioned.centerY)))">"#)

    if let title = positioned.title {
        parts.append(
            #"<text class="radarTitle" x="\#(_rN(title.x))" y="\#(_rN(title.y))" dominant-baseline="hanging" text-anchor="middle">\#(SVG.escapeText(title.text))</text>"#
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
            #"<text class="radarAxisLabel" x="\#(_rN(label.x))" y="\#(_rN(label.y))" dominant-baseline="middle" text-anchor="middle">\#(SVG.escapeText(label.text))</text>"#
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
            parts.append(#"<text class="radarLegendText" x="16" y="0" dominant-baseline="hanging" text-anchor="start">\#(SVG.escapeText(item.label))</text>"#)
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
    css += ".radarTitle { font-size: \(_safeInt(theme.fontSize, default: 0))px; color: \(SVG.escapeText(theme.titleColor)); dominant-baseline: hanging; text-anchor: middle; }\n"
    css += ".radarAxisLine { stroke: \(SVG.escapeText(theme.axisColor)); stroke-width: \(_safeInt(theme.axisStrokeWidth, default: 0)); }\n"
    css += ".radarAxisLabel { dominant-baseline: middle; text-anchor: middle; font-size: \(_safeInt(theme.axisLabelFontSize, default: 0))px; color: \(SVG.escapeText(theme.axisColor)); }\n"
    css += ".radarGraticule { fill: \(SVG.escapeText(theme.graticuleColor)); fill-opacity: \(_rN(theme.graticuleOpacity)); stroke: \(SVG.escapeText(theme.graticuleColor)); stroke-width: \(_safeInt(theme.graticuleStrokeWidth, default: 0)); }\n"
    if includeLegend {
        css += ".radarLegendText { text-anchor: start; font-size: \(_safeInt(theme.legendFontSize, default: 0))px; dominant-baseline: hanging; }\n"
    }

    // `themeColorLimit` comes from frontmatter: a negative value trapped
    // the range, a huge one built megabytes of CSS.
    for i in 0..<min(max(0, theme.themeColorLimit), 256) {
        let color = SVG.escapeText(theme.curveColor(at: i))
        css += ".radarCurve-\(i) { color: \(color); fill: \(color); fill-opacity: \(_rN(theme.curveOpacity)); stroke: \(color); stroke-width: \(_safeInt(theme.curveStrokeWidth, default: 0)); }\n"
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
    let builder = SVGDocumentBuilder(
        width: positioned.width, height: positioned.height,
        colors: colors, transparent: transparent,
        fontFamily: font,
        useMaxWidth: positioned.config.useMaxWidth
    )
    return builder.open(extraAttributes: #"id="graphDiv""#)
}

// MARK: - XML escaping and number formatting

private func _rN(_ n: Double) -> String {
    let rounded = (n * 10).rounded() / 10
    if rounded.isFinite && abs(rounded) < 1e15 && rounded == rounded.rounded() {
        return String(Int(rounded))
    }
    if !rounded.isFinite { return "0" }
    return String(format: "%.1f", rounded)
}
