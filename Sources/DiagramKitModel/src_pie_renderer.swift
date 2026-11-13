import Foundation
import DiagramKitCommon

// MARK: - Public entry point

public func renderPieSvg(
    _ chart: PositionedPieChart,
    _ colors: DiagramColors,
    _ font: String = DiagramSVGFontFamily.proportional,
    _ transparent: Bool = false
) -> String {
    var parts: [String] = []

    let useMaxWidth = chart.config.useMaxWidth
    let _builder = SVGDocumentBuilder(
        width: chart.width, height: chart.height,
        colors: colors, transparent: transparent,
        fontFamily: font,
        useMaxWidth: useMaxWidth,
        viewBoxX: chart.viewBoxX
    )
    parts.append(_builder.open())

    // Accessibility
    if let accTitle = chart.accTitle {
        parts.append("<title>\(SVG.escapeText(accTitle))</title>")
    }
    if let accDescr = chart.accDescr {
        parts.append("<desc>\(SVG.escapeText(accDescr))</desc>")
    }

    // CSS styles
    let pieStroke = _isSafeCSSColor(chart.theme.pieStrokeColor) ? chart.theme.pieStrokeColor : "var(--line)"
    let pieOuterStroke = _isSafeCSSColor(chart.theme.pieOuterStrokeColor) ? chart.theme.pieOuterStrokeColor : "var(--line)"
    let pieTitleTextColor = _isSafeCSSColor(chart.theme.resolvedPieTitleTextColor) ? chart.theme.resolvedPieTitleTextColor : "var(--_text)"
    let pieSectionTextColor = _isSafeCSSColor(chart.theme.resolvedPieSectionTextColor) ? chart.theme.resolvedPieSectionTextColor : "var(--_text)"
    let pieLegendTextColor = _isSafeCSSColor(chart.theme.resolvedPieLegendTextColor) ? chart.theme.resolvedPieLegendTextColor : "var(--_text)"
    let pieFontFamily = SVG.escapeText(chart.theme.resolvedFontFamily)
    // Theme sizes are copied into the `<style>` block; an unsafe value
    // (`2px}</style><script>…`) falls back to the default.
    parts.append("<style>")
    parts.append("""
    .pieCircle{
      stroke: \(SVG.escapeText(pieStroke));
      stroke-width : \(SVG.cssValue(chart.theme.pieStrokeWidth, fallback: "2px"));
      opacity : \(SVG.cssValue(chart.theme.pieOpacity, fallback: "0.7"));
    }
    .pieOuterCircle{
      stroke: \(SVG.escapeText(pieOuterStroke));
      stroke-width: \(SVG.cssValue(chart.theme.pieOuterStrokeWidth, fallback: "2px"));
      fill: none;
    }
    .pieTitleText {
      text-anchor: middle;
      font-size: \(SVG.cssValue(chart.theme.pieTitleTextSize, fallback: "25px"));
      fill: \(SVG.escapeText(pieTitleTextColor));
      font-family: \(pieFontFamily);
    }
    .slice {
      text-anchor: middle;
      font-family: \(pieFontFamily);
      fill: \(SVG.escapeText(pieSectionTextColor));
      font-size:\(SVG.cssValue(chart.theme.pieSectionTextSize, fallback: "17px"));
    }
    .legend text {
      fill: \(SVG.escapeText(pieLegendTextColor));
      font-family: \(pieFontFamily);
      font-size: \(SVG.cssValue(chart.theme.pieLegendTextSize, fallback: "17px"));
    }
    """)
    parts.append("</style>")

    // Group centered at pie center
    let cx = 225.0
    let cy = 225.0
    parts.append(#"<g transform="translate(\#(_pieR(cx)), \#(_pieR(cy)))">"#)

    // Outer circle
    parts.append(
        #"<circle cx="0" cy="0" r="\#(_pieR(chart.outerCircle.r))" class="pieOuterCircle"/>"#
    )

    // Resolve base colors for pie palette derivation
    let basePrimary = colors.accent ?? "#ECECFF"
    let baseSecondary = PieChartThemeConfig.adjustHSL(basePrimary, hShift: 60, lShift: -10)
    let baseTertiary = PieChartThemeConfig.adjustHSL(basePrimary, hShift: -60, lShift: -10)

    // Pie arcs
    for arc in chart.arcs {
        let fillColor = chart.theme.resolvedPieColor(at: arc.fillColorIndex, primary: basePrimary, secondary: baseSecondary, tertiary: baseTertiary)
        parts.append(
            #"<path d="\#(SVG.escapeText(arc.path))" fill="\#(SVG.escapeText(fillColor))" class="pieCircle"/>"#
        )
    }

    // Slice labels
    for label in chart.sliceLabels {
        parts.append(
            #"<text transform="translate(\#(_pieR(label.x)), \#(_pieR(label.y)))" class="slice">\#(SVG.escapeText(label.text))</text>"#
        )
    }

    // Title
    if let title = chart.title {
        parts.append(
            #"<text x="\#(_pieR(title.x))" y="\#(_pieR(title.y))" class="pieTitleText">\#(SVG.escapeText(title.text))</text>"#
        )
    }

    // Legend
    if !chart.legend.isEmpty {
        parts.append(#"<g class="legend">"#)
        for entry in chart.legend {
            let fillColor = chart.theme.resolvedPieColor(at: entry.colorIndex, primary: basePrimary, secondary: baseSecondary, tertiary: baseTertiary)
            let groupTransform = "translate(\(_pieR(entry.x)), \(_pieR(entry.y)))"
            parts.append(#"<g transform="\#(groupTransform)">"#)
            parts.append(
                #"<rect width="18" height="18" fill="\#(SVG.escapeText(fillColor))" stroke="\#(SVG.escapeText(fillColor))"/>"#
            )
            parts.append(
                #"<text x="22" y="14">\#(SVG.escapeText(entry.displayText))</text>"#
            )
            parts.append("</g>")
        }
        parts.append("</g>")
    }

    parts.append("</g>")
    parts.append(_builder.close())

    return parts.joined(separator: "\n")
}

// MARK: - Utilities

private func _pieR(_ n: Double) -> String {
    let rounded = (n * 10).rounded() / 10
    if rounded.isFinite && abs(rounded) < 1e15 && rounded == rounded.rounded() {
        return _integralText(rounded)
    }
    if !rounded.isFinite { return "0" }
    return String(format: "%.1f", rounded)
}

