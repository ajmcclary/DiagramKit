import Foundation
import DiagramKitCommon

public func renderEventModelingSvg(
    _ positioned: PositionedEventModelingDiagram,
    diagramId: String,
    colors: DiagramColors,
    font: String,
    transparent: Bool
) -> String {
    let config = positioned.config
    let theme = positioned.themeVariables
    let bg = transparent ? "none" : colors.bg
    let fg = colors.fg
    let padding = max(0, config.padding)
    let vbx = -padding
    let vby = -padding
    let vbw = positioned.width + 2 * padding
    let vbh = positioned.height + 2 * padding

    var svg = ""
    let _builder = SVGDocumentBuilder(
        width: vbw, height: vbh,
        colors: colors, transparent: transparent,
        fontFamily: font,
        useMaxWidth: config.useMaxWidth,
        viewBoxX: vbx, viewBoxY: vby
    )
    svg += _builder.open() + ">"
    if !transparent {
        svg += "<rect x=\"\(emFmt(vbx))\" y=\"\(emFmt(vby))\" width=\"\(emFmt(vbw))\" height=\"\(emFmt(vbh))\" fill=\"\(svmEscape(bg))\"/>"
    }

    // Accessibility
    if let title = positioned.diagramTitle {
        svg += "<title>\(svmEscape(title))</title>"
    }
    if let accTitle = positioned.accTitle {
        svg += "<desc>\(svmEscape(accTitle))</desc>"
    }
    if let accDescr = positioned.accDescr {
        svg += "<desc>\(svmEscape(accDescr))</desc>"
    }

    let markerId = "em-arrowhead-\(diagramId)"

    // Defs
    svg += "<defs>"
    svg += "<marker id=\"\(markerId)\" markerWidth=\"10\" markerHeight=\"7\" refX=\"10\" refY=\"3.5\" orient=\"auto\">"
    svg += "<polygon points=\"0 0, 10 3.5, 0 7\" fill=\"\(svmEscape(theme.arrowhead))\"/>"
    svg += "</marker>"
    svg += "</defs>"

    // Swimlanes
    for sl in positioned.swimlanes {
        let bgFill = theme.swimlaneBackgroundOdd
        let bgStroke = theme.swimlaneBackgroundStroke
        let maxR = positioned.swimlanes.map(\.r).max() ?? 250
        let swimWidth = maxR + 15 // swimlanePadding

        svg += "<g class=\"em-swimlane\">"
        svg += "<rect x=\"0\" y=\"\(emFmt(sl.y))\" rx=\"3\" width=\"\(emFmt(swimWidth))\" height=\"\(emFmt(sl.height))\" fill=\"\(svmEscape(bgFill))\" stroke=\"\(svmEscape(bgStroke))\"/>"
        svg += "<text font-weight=\"bold\" x=\"30\" y=\"\(sl.y + 30)\" fill=\"\(fg)\">\(svmEscape(sl.label))</text>"
        svg += "</g>"
    }

    // Boxes
    for box in positioned.boxes {
        svg += "<g class=\"em-box\">"
        svg += "<rect x=\"\(box.x)\" y=\"\(box.y)\" rx=\"3\" width=\"\(box.width)\" height=\"\(box.height)\" fill=\"\(box.fill)\" stroke=\"\(box.stroke)\"/>"

        let foreignX = box.x + 10 // boxPadding
        let foreignY = box.y + 10
        let foreignW = box.width - 20
        let foreignH = box.height - 20

        svg += "<foreignObject x=\"\(foreignX)\" y=\"\(foreignY)\" width=\"\(foreignW)\" height=\"\(foreignH)\">"
        svg += "<xhtml:div style=\"display: table; height: 100%; width: 100%\">"
        svg += "<span style=\"display: table-cell; text-align: center; vertical-align: middle\">"
        svg += box.textContent
        svg += "</span>"
        svg += "</xhtml:div>"
        svg += "</foreignObject>"

        svg += "</g>"
    }

    // Relations
    for rel in positioned.relations {
        let stroke = rel.stroke
        svg += "<path class=\"em-relation\" fill=\"none\" stroke=\"\(svmEscape(stroke))\" stroke-width=\"1\" marker-end=\"url(#\(markerId))\" d=\"M\(emFmt(rel.sourceX)) \(emFmt(rel.sourceY)) L\(emFmt(rel.targetX)) \(emFmt(rel.targetY))\"/>"
    }

    svg += _builder.close()
    return svg
}

private func emFmt(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }
    var text = String(format: "%.3f", value)
    while text.last == "0" { text.removeLast() }
    if text.last == "." { text.removeLast() }
    return text
}

private func svmEscape(_ text: String) -> String {
    SVG.escapeText(text)
}
