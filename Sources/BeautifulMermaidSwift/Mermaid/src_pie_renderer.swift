import Foundation

// MARK: - Public entry point

public func renderPieSvg(
    _ chart: PositionedPieChart,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false
) -> String {
    var parts: [String] = []

    let themeColors = original_src_theme.DiagramColors(bg: colors.bg, fg: colors.fg, line: colors.line, accent: colors.accent, muted: colors.muted, surface: colors.surface, border: colors.border)
    let svgTag = original_src_theme.svgOpenTag(
        chart.width,
        chart.height,
        themeColors,
        transparent,
        viewBoxX: chart.viewBoxX
    )
    parts.append(svgTag)

    // Accessibility
    if let accTitle = chart.accTitle {
        parts.append("<title>\(_escapePieXml(accTitle))</title>")
    }
    if let accDescr = chart.accDescr {
        parts.append("<desc>\(_escapePieXml(accDescr))</desc>")
    }

    // CSS styles
    parts.append("<style>")
    parts.append("""
    .pieCircle{
      stroke: \(chart.theme.pieStrokeColor);
      stroke-width : \(chart.theme.pieStrokeWidth);
      opacity : \(chart.theme.pieOpacity);
    }
    .pieOuterCircle{
      stroke: \(chart.theme.pieOuterStrokeColor);
      stroke-width: \(chart.theme.pieOuterStrokeWidth);
      fill: none;
    }
    .pieTitleText {
      text-anchor: middle;
      font-size: \(chart.theme.pieTitleTextSize);
      fill: \(chart.theme.resolvedPieTitleTextColor);
      font-family: \(chart.theme.resolvedFontFamily);
    }
    .slice {
      text-anchor: middle;
      font-family: \(chart.theme.resolvedFontFamily);
      fill: \(chart.theme.resolvedPieSectionTextColor);
      font-size:\(chart.theme.pieSectionTextSize);
    }
    .legend text {
      fill: \(chart.theme.resolvedPieLegendTextColor);
      font-family: \(chart.theme.resolvedFontFamily);
      font-size: \(chart.theme.pieLegendTextSize);
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

    // Pie arcs
    for arc in chart.arcs {
        let fillColor = chart.theme.pieColor(at: arc.fillColorIndex)
        parts.append(
            #"<path d="\#(_escapePieXml(arc.path))" fill="\#(_escapePieXml(fillColor))" class="pieCircle"/>"#
        )
    }

    // Slice labels
    for label in chart.sliceLabels {
        parts.append(
            #"<text transform="translate(\#(_pieR(label.x)), \#(_pieR(label.y)))" class="slice">\#(_escapePieXml(label.text))</text>"#
        )
    }

    // Title
    if let title = chart.title {
        parts.append(
            #"<text x="\#(_pieR(title.x))" y="\#(_pieR(title.y))" class="pieTitleText">\#(_escapePieXml(title.text))</text>"#
        )
    }

    // Legend
    if !chart.legend.isEmpty {
        parts.append(#"<g class="legend">"#)
        for entry in chart.legend {
            let fillColor = chart.theme.pieColor(at: entry.colorIndex)
            let groupTransform = "translate(\(_pieR(entry.x)), \(_pieR(entry.y)))"
            parts.append(#"<g transform="\#(groupTransform)">"#)
            parts.append(
                #"<rect width="18" height="18" fill="\#(_escapePieXml(fillColor))" stroke="\#(_escapePieXml(fillColor))"/>"#
            )
            parts.append(
                #"<text x="22" y="14">\#(_escapePieXml(entry.displayText))</text>"#
            )
            parts.append("</g>")
        }
        parts.append("</g>")
    }

    parts.append("</g>")
    parts.append("</svg>")

    return parts.joined(separator: "\n")
}

// MARK: - Utilities

private func _pieR(_ n: Double) -> String {
    let rounded = (n * 10).rounded() / 10
    if rounded.isFinite && abs(rounded) < 1e15 && rounded == rounded.rounded() {
        return String(Int(rounded))
    }
    if !rounded.isFinite { return "0" }
    return String(format: "%.1f", rounded)
}

private func _escapePieXml(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}
