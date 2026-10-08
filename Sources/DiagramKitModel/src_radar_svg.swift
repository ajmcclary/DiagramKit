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
