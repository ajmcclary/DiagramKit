import Foundation

// MARK: - Public entry point

public func renderQuadrantSvg(
    _ chart: PositionedQuadrantChart,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false
) -> String {
    var parts: [String] = []

    let svgTag = _quadrantSvgOpenTag(chart, colors, transparent)
    parts.append(svgTag)

    if let accTitle = chart.accTitle {
        parts.append("<title>\(_escapeQuadrantXml(accTitle))</title>")
    }
    if let accDescr = chart.accDescr {
        parts.append("<desc>\(_escapeQuadrantXml(accDescr))</desc>")
    }

    parts.append(#"<g class="main">"#)

    parts.append(#"<g class="quadrants">"#)
    for quadrant in chart.quadrants {
        parts.append(#"<g class="quadrant">"#)
        parts.append(
            #"<rect x="\#(_qR(quadrant.x))" y="\#(_qR(quadrant.y))" width="\#(_qR(quadrant.width))" height="\#(_qR(quadrant.height))" fill="\#(_escapeQuadrantXml(quadrant.fill))"/>"#
        )
        parts.append(
            #"<text x="0" y="0" fill="\#(_escapeQuadrantXml(quadrant.text.fill))" font-size="\#(_qR(quadrant.text.fontSize))" dominant-baseline="\#(_dominantBaseline(quadrant.text.horizontalPos))" text-anchor="\#(_textAnchor(quadrant.text.verticalPos))" transform="\#(_transformation(quadrant.text.x, quadrant.text.y, quadrant.text.rotation))">\#(_escapeQuadrantXml(quadrant.text.text))</text>"#
        )
        parts.append("</g>")
    }
    parts.append("</g>")

    parts.append(#"<g class="border">"#)
    for line in chart.borderLines {
        parts.append(
            #"<line x1="\#(_qR(line.x1))" y1="\#(_qR(line.y1))" x2="\#(_qR(line.x2))" y2="\#(_qR(line.y2))" style="stroke: \#(_escapeQuadrantXml(line.strokeFill)); stroke-width: \#(_qR(line.strokeWidth));"/>"#
        )
    }
    parts.append("</g>")

    parts.append(#"<g class="data-points">"#)
    for point in chart.points {
        parts.append(#"<g class="data-point">"#)
        parts.append(
            #"<circle cx="\#(_qR(point.x))" cy="\#(_qR(point.y))" r="\#(_qR(point.radius))" fill="\#(_escapeQuadrantXml(point.fill))" stroke="\#(_escapeQuadrantXml(point.strokeColor))" stroke-width="\#(_escapeQuadrantXml(point.strokeWidth))"/>"#
        )
        parts.append(
            #"<text x="0" y="0" fill="\#(_escapeQuadrantXml(point.text.fill))" font-size="\#(_qR(point.text.fontSize))" dominant-baseline="\#(_dominantBaseline(point.text.horizontalPos))" text-anchor="\#(_textAnchor(point.text.verticalPos))" transform="\#(_transformation(point.text.x, point.text.y, point.text.rotation))">\#(_escapeQuadrantXml(point.text.text))</text>"#
        )
        parts.append("</g>")
    }
    parts.append("</g>")

    parts.append(#"<g class="labels">"#)
    for label in chart.axisLabels {
        parts.append(#"<g class="label">"#)
        parts.append(
            #"<text x="0" y="0" fill="\#(_escapeQuadrantXml(label.fill))" font-size="\#(_qR(label.fontSize))" dominant-baseline="\#(_dominantBaseline(label.horizontalPos))" text-anchor="\#(_textAnchor(label.verticalPos))" transform="\#(_transformation(label.x, label.y, label.rotation))">\#(_escapeQuadrantXml(label.text))</text>"#
        )
        parts.append("</g>")
    }
    parts.append("</g>")

    parts.append(#"<g class="title">"#)
    if let title = chart.title {
        parts.append(
            #"<text x="0" y="0" fill="\#(_escapeQuadrantXml(title.fill))" font-size="\#(_qR(title.fontSize))" dominant-baseline="\#(_dominantBaseline(title.horizontalPos))" text-anchor="\#(_textAnchor(title.verticalPos))" transform="\#(_transformation(title.x, title.y, title.rotation))">\#(_escapeQuadrantXml(title.text))</text>"#
        )
    }
    parts.append("</g>")

    parts.append("</g>")
    parts.append("</svg>")

    return parts.joined(separator: "\n")
}

// MARK: - SVG helpers

private func _dominantBaseline(_ horizontalPos: String) -> String {
    horizontalPos == "top" ? "hanging" : "middle"
}

private func _textAnchor(_ verticalPos: String) -> String {
    verticalPos == "left" ? "start" : "middle"
}

private func _transformation(_ x: Double, _ y: Double, _ rotation: Double) -> String {
    "translate(\(_qR(x)), \(_qR(y))) rotate(\(_qR(rotation)))"
}

private func _qR(_ n: Double) -> String {
    let rounded = (n * 10).rounded() / 10
    if rounded.isFinite && abs(rounded) < 1e15 && rounded == rounded.rounded() {
        return String(Int(rounded))
    }
    if !rounded.isFinite { return "0" }
    return String(format: "%.1f", rounded)
}

private func _escapeQuadrantXml(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}

private func _quadrantSvgOpenTag(
    _ chart: PositionedQuadrantChart,
    _ colors: DiagramColors,
    _ transparent: Bool
) -> String {
    let widthStr = _qR(chart.width)
    let heightStr = _qR(chart.height)
    let bg = transparent ? "none" : colors.bg

    var attrs: [String] = [
        #"id="graphDiv""#,
        #"xmlns="http://www.w3.org/2000/svg""#,
        #"viewBox="0 0 \#(widthStr) \#(heightStr)""#,
        #"role="graphics-document document""#,
        #"aria-roledescription="quadrant-chart""#,
    ]

    var styles: [String] = []
    if chart.config.useMaxWidth {
        attrs.append(#"width="100%""#)
        attrs.append(#"preserveAspectRatio="xMinYMin meet""#)
        styles.append("max-width: \(widthStr)px")
    } else {
        attrs.append(#"width="\#(widthStr)""#)
        attrs.append(#"height="\#(heightStr)""#)
    }
    styles.append("background-color: \(bg)")
    attrs.append(#"style="\#(styles.joined(separator: "; "))""#)

    return "<svg \(attrs.joined(separator: " "))>"
}
