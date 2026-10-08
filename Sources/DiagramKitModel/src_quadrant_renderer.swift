import Foundation
import DiagramKitCommon

// MARK: - Public entry point

public func renderQuadrantSvg(
    _ chart: PositionedQuadrantChart,
    _ colors: DiagramColors,
    _ font: String = DiagramSVGFontFamily.proportional,
    _ transparent: Bool = false
) -> String {
    var parts: [String] = []

    let svgTag = _quadrantSvgOpenTag(chart, colors, font, transparent)
    parts.append(svgTag)

    if let accTitle = chart.accTitle {
        parts.append("<title>\(SVG.escapeText(accTitle))</title>")
    }
    if let accDescr = chart.accDescr {
        parts.append("<desc>\(SVG.escapeText(accDescr))</desc>")
    }

    parts.append(#"<g class="main">"#)

    parts.append(#"<g class="quadrants">"#)
    for quadrant in chart.quadrants {
        parts.append(#"<g class="quadrant">"#)
        parts.append(
            #"<rect x="\#(_qR(quadrant.x))" y="\#(_qR(quadrant.y))" width="\#(_qR(quadrant.width))" height="\#(_qR(quadrant.height))" fill="\#(SVG.escapeText(quadrant.fill))"/>"#
        )
        parts.append(
            #"<text x="0" y="0" fill="\#(SVG.escapeText(quadrant.text.fill))" font-size="\#(_qR(quadrant.text.fontSize))" dominant-baseline="\#(_dominantBaseline(quadrant.text.horizontalPos))" text-anchor="\#(_textAnchor(quadrant.text.verticalPos))" transform="\#(_transformation(quadrant.text.x, quadrant.text.y, quadrant.text.rotation))">\#(SVG.escapeText(quadrant.text.text))</text>"#
        )
        parts.append("</g>")
    }
    parts.append("</g>")

    parts.append(#"<g class="border">"#)
    for line in chart.borderLines {
        parts.append(
            #"<line x1="\#(_qR(line.x1))" y1="\#(_qR(line.y1))" x2="\#(_qR(line.x2))" y2="\#(_qR(line.y2))" style="stroke: \#(SVG.escapeText(line.strokeFill)); stroke-width: \#(_qR(line.strokeWidth));"/>"#
        )
    }
    parts.append("</g>")

    parts.append(#"<g class="data-points">"#)
    for point in chart.points {
        parts.append(#"<g class="data-point">"#)
        parts.append(
            #"<circle cx="\#(_qR(point.x))" cy="\#(_qR(point.y))" r="\#(_qR(point.radius))" fill="\#(SVG.escapeText(point.fill))" stroke="\#(SVG.escapeText(point.strokeColor))" stroke-width="\#(SVG.escapeText(point.strokeWidth))"/>"#
        )
        parts.append(
            #"<text x="0" y="0" fill="\#(SVG.escapeText(point.text.fill))" font-size="\#(_qR(point.text.fontSize))" dominant-baseline="\#(_dominantBaseline(point.text.horizontalPos))" text-anchor="\#(_textAnchor(point.text.verticalPos))" transform="\#(_transformation(point.text.x, point.text.y, point.text.rotation))">\#(SVG.escapeText(point.text.text))</text>"#
        )
        parts.append("</g>")
    }
    parts.append("</g>")

    parts.append(#"<g class="labels">"#)
    for label in chart.axisLabels {
        parts.append(#"<g class="label">"#)
        parts.append(
            #"<text x="0" y="0" fill="\#(SVG.escapeText(label.fill))" font-size="\#(_qR(label.fontSize))" dominant-baseline="\#(_dominantBaseline(label.horizontalPos))" text-anchor="\#(_textAnchor(label.verticalPos))" transform="\#(_transformation(label.x, label.y, label.rotation))">\#(SVG.escapeText(label.text))</text>"#
        )
        parts.append("</g>")
    }
    parts.append("</g>")

    parts.append(#"<g class="title">"#)
    if let title = chart.title {
        parts.append(
            #"<text x="0" y="0" fill="\#(SVG.escapeText(title.fill))" font-size="\#(_qR(title.fontSize))" dominant-baseline="\#(_dominantBaseline(title.horizontalPos))" text-anchor="\#(_textAnchor(title.verticalPos))" transform="\#(_transformation(title.x, title.y, title.rotation))">\#(SVG.escapeText(title.text))</text>"#
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

private func _quadrantSvgOpenTag(
    _ chart: PositionedQuadrantChart,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) -> String {
    // Inject `font-family` into the root <svg style="…"> so the caller-
    // supplied family propagates to every text child via CSS inheritance
    // — quadrant text elements have no inline `font-family`, so the root
    // style is the single point where the font reaches the rendered SVG.
    let builder = SVGDocumentBuilder(
        width: chart.width, height: chart.height,
        colors: colors, transparent: transparent,
        fontFamily: font,
        useMaxWidth: chart.config.useMaxWidth,
        rootStyles: ["font-family:\(font)"]
    )
    return builder.open(extraAttributes: #"id="graphDiv" aria-roledescription="quadrant-chart""#)
}
