import Foundation

func renderVennSvg(
    _ positioned: PositionedVennDiagram,
    diagramId: String,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) -> String {
    var svg = ""

    svg += "<svg id=\"\(diagramId)\" viewBox=\"0 0 \(Int(positioned.width)) \(Int(positioned.height))\" xmlns=\"http://www.w3.org/2000/svg\">\n"

    if let accTitle = positioned.accTitle {
        svg += "<title>\(_escapeXml(accTitle))</title>\n"
    }
    if let accDescr = positioned.accDescr {
        svg += "<desc>\(_escapeXml(accDescr))</desc>\n"
    }

    if !transparent {
        svg += "<rect width=\"100%\" height=\"100%\" fill=\"\(colors.bg)\" />\n"
    }

    let titleColor = positioned.themeVariables?["vennTitleTextColor"] ?? colors.fg

    if let title = positioned.title {
        svg += "<text class=\"venn-title\" x=\"50%\" y=\"\(Int(title.y))\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"\(font)\" font-size=\"\(Int(title.fontSize))px\" fill=\"\(titleColor)\">\(_escapeXml(title.text))</text>\n"
    }

    svg += "<g transform=\"translate(0, \(Int(positioned.titleHeight)))\">\n"

    for area in positioned.areas {
        svg += renderVennAreaSvg(area, font: font)
    }

    if !positioned.textNodes.isEmpty {
        svg += "<g class=\"venn-text-nodes\">\n"
        for node in positioned.textNodes {
            svg += renderVennTextNodeSvg(node, font: font, scale: positioned.scale, debugLayout: positioned.useDebugLayout)
        }
        svg += "</g>\n"
    }

    svg += "</g>\n"

    if positioned.config.useMaxWidth {
        svg += "<style>#\(diagramId) { max-width: 100%; }</style>\n"
    }

    svg += "</svg>"

    return svg
}

private func renderVennAreaSvg(_ area: PositionedVennArea, font: String) -> String {
    var result = ""

    if area.isSingleSet {
        result += renderVennCircleSvg(area, font: font)
    } else {
        result += renderVennIntersectionSvg(area, font: font)
    }

    return result
}

private func renderVennCircleSvg(_ area: PositionedVennArea, font: String) -> String {
    var result = ""
    let fmt: (Double) -> String = { String(format: "%.2f", $0) }

    for circle in area.circles {
        result += "<g class=\"venn-circle \(area.colorClass)\">\n"

        let fillOpacity = area.fillOpacity
        let strokeOpacity = 0.95

        if area.debugFlags {
            result += "<circle cx=\"\(fmt(circle.center.x))\" cy=\"\(fmt(circle.center.y))\" r=\"\(fmt(circle.radius))\" fill=\"none\" stroke=\"purple\" stroke-width=\"1\" stroke-dasharray=\"4 2\" />\n"
        }

        result += "<circle cx=\"\(fmt(circle.center.x))\" cy=\"\(fmt(circle.center.y))\" r=\"\(fmt(circle.radius))\" fill=\"\(area.fillColor)\" fill-opacity=\"\(String(format: "%.3f", fillOpacity))\" stroke=\"\(area.strokeColor)\" stroke-width=\"\(fmt(area.strokeWidth))\" stroke-opacity=\"\(String(format: "%.3f", strokeOpacity))\" />\n"

        let labelText = area.label ?? area.sets.first ?? ""
        if !labelText.isEmpty {
            result += "<text x=\"\(fmt(circle.center.x))\" y=\"\(fmt(circle.center.y))\" font-size=\"\(Int(area.textFontSize))px\" fill=\"\(area.textColor)\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"\(font)\">\(_escapeXml(labelText))</text>\n"
        }

        result += "</g>\n"
    }

    return result
}

private func renderVennIntersectionSvg(_ area: PositionedVennArea, font: String) -> String {
    var result = ""
    let fmt: (Double) -> String = { String(format: "%.2f", $0) }

    result += "<g class=\"venn-intersection\">\n"

    if let pathSpec = area.pathSpec {
        let fill = area.fillColor
        let fillOpacity = area.fillOpacity
        result += "<path d=\"\(pathSpec)\" fill=\"\(fill)\" fill-opacity=\"\(String(format: "%.3f", fillOpacity))\" stroke=\"\(area.strokeColor)\" stroke-width=\"\(fmt(area.strokeWidth))\" />\n"
    }

    let labelText = area.label ?? area.sets.joined(separator: " & ")
    if !labelText.isEmpty {
        result += "<text x=\"\(fmt(area.textPoint.x))\" y=\"\(fmt(area.textPoint.y))\" font-size=\"\(Int(area.textFontSize))px\" fill=\"\(area.textColor)\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"\(font)\">\(_escapeXml(labelText))</text>\n"
    }

    result += "</g>\n"

    return result
}

private func renderVennTextNodeSvg(_ node: PositionedVennTextNode, font: String, scale: Double, debugLayout: Bool) -> String {
    var result = ""
    let fmt: (Double) -> String = { String(format: "%.2f", $0) }

    result += "<g class=\"venn-text-area\">\n"

    let displayText = node.label ?? node.id

    result += "<foreignObject class=\"venn-text-node-fo\" width=\"\(fmt(node.width))\" height=\"\(fmt(node.height))\" x=\"\(fmt(node.x))\" y=\"\(fmt(node.y))\" overflow=\"visible\">\n"
    result += "<span xmlns=\"http://www.w3.org/1999/xhtml\" class=\"venn-text-node\" style=\"display:flex;width:100%;height:100%;align-items:center;justify-content:center;text-align:center;color:\(node.textColor);font-family:\(font);font-size:\(Int(12 * max(scale, 0.3)))px;word-wrap:break-word;overflow-wrap:break-word;\">\(_escapeXml(displayText))</span>\n"
    result += "</foreignObject>\n"

    if debugLayout {
        result += "<circle class=\"venn-text-debug-circle\" cx=\"\(fmt(node.x + node.width / 2))\" cy=\"\(fmt(node.y + node.height / 2))\" r=\"5\" fill=\"none\" stroke=\"purple\" stroke-width=\"1\" stroke-dasharray=\"3 2\" />\n"
        result += "<rect class=\"venn-text-debug-cell\" x=\"\(fmt(node.x))\" y=\"\(fmt(node.y))\" width=\"\(fmt(node.width))\" height=\"\(fmt(node.height))\" fill=\"none\" stroke=\"teal\" stroke-width=\"1\" stroke-dasharray=\"3 2\" />\n"
    }

    result += "</g>\n"

    return result
}

private func _escapeXml(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
     .replacingOccurrences(of: "<", with: "&lt;")
     .replacingOccurrences(of: ">", with: "&gt;")
     .replacingOccurrences(of: "\"", with: "&quot;")
     .replacingOccurrences(of: "'", with: "&apos;")
}
