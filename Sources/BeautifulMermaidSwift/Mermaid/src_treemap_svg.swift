import Foundation

func renderTreemapSvg(
    _ positioned: PositionedTreemapDiagram,
    diagramId: String,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) -> String {
    var svg = ""

    svg += "<svg viewBox=\"0 0 \(Int(positioned.svgWidth)) \(Int(positioned.svgHeight))\" xmlns=\"http://www.w3.org/2000/svg\">\n"

    if !transparent {
        svg += "<rect width=\"100%\" height=\"100%\" fill=\"\(colors.bg)\" />\n"
    }

    if let title = positioned.title {
        let titleColor = positioned.themeVariables?["titleColor"] ?? colors.fg
        svg += "<text class=\"treemapTitle\" x=\"\(Int(title.x))\" y=\"\(Int(title.y))\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"\(font)\" font-size=\"14px\" fill=\"\(titleColor)\">\(_escapeXml(title.text))</text>\n"
    }

    svg += "<g class=\"treemapContainer\" transform=\"translate(0, \(Int(positioned.titleHeight)))\">\n"

    for section in positioned.sections {
        svg += _renderSectionSvg(section, font: font)
    }

    for leaf in positioned.leaves {
        svg += _renderLeafSvg(leaf, font: font)
    }

    svg += "</g>\n"

    svg += "</svg>"

    return svg
}

private func _renderSectionSvg(_ section: PositionedTreemapSection, font: String) -> String {
    let w = Int(section.x1 - section.x0)
    let h = Int(section.y1 - section.y0)

    let hiddenStyle = section.depth == 0 ? " style=\"display: none;\"" : ""

    var result = ""
    result += "<g class=\"treemapSection\" transform=\"translate(\(Int(section.x0)),\(Int(section.y0)))\">\n"

    result += "<rect class=\"treemapSectionHeader\" width=\"\(w)\" height=\"25\" fill=\"none\" fill-opacity=\"0.6\" stroke-width=\"0.6\"\(hiddenStyle)/>\n"

    let clipW = max(0, w - 12)
    result += "<clipPath id=\"\(section.clipId)\">\n"
    result += "<rect width=\"\(clipW)\" height=\"25\" />\n"
    result += "</clipPath>\n"

    result += "<rect class=\"treemapSection section\(section.index)\" width=\"\(w)\" height=\"\(max(0, h - 25))\" x=\"0\" y=\"25\" fill=\"\(section.fillColor)\" fill-opacity=\"0.6\" stroke=\"\(section.strokeColor)\" stroke-width=\"2.0\" stroke-opacity=\"0.4\"\(hiddenStyle)/>\n"

    if let label = section.label, !label.hidden {
        let labelStyle = _textStyle(label, font: font, clipId: section.clipId, hidden: section.depth == 0)
        result += "<text class=\"treemapSectionLabel\" x=\"6\" y=\"\(Int(SECTION_HEADER_HEIGHT / 2))\" dominant-baseline=\"middle\" font-weight=\"bold\" font-family=\"\(font)\"\(labelStyle)>\(_escapeXml(label.text))</text>\n"
    }

    if let value = section.value, !value.hidden, section.depth != 0 {
        let valueStyle = _textStyle(value, font: font, clipId: section.clipId, hidden: false)
        result += "<text class=\"treemapSectionValue\" x=\"\(w - 10)\" y=\"\(Int(SECTION_HEADER_HEIGHT / 2))\" text-anchor=\"end\" dominant-baseline=\"middle\" font-style=\"italic\" font-family=\"\(font)\"\(valueStyle)>\(_escapeXml(value.text))</text>\n"
    }

    result += "</g>\n"

    return result
}

private func _renderLeafSvg(_ leaf: PositionedTreemapLeaf, font: String) -> String {
    let w = Int(leaf.x1 - leaf.x0)
    let h = Int(leaf.y1 - leaf.y0)

    var classes = "treemapNode treemapLeafGroup leaf\(leaf.index)"
    if let sel = leaf.classSelector { classes += " \(sel)" }

    var result = ""
    result += "<g class=\"\(classes)\" transform=\"translate(\(Int(leaf.x0)),\(Int(leaf.y0)))\">\n"

    result += "<rect class=\"treemapLeaf\" width=\"\(w)\" height=\"\(h)\" fill=\"\(leaf.fillColor)\" fill-opacity=\"0.3\" stroke=\"\(leaf.strokeColor)\" stroke-width=\"3.0\" />\n"

    let clipW = max(0, w - 4)
    let clipH = max(0, h - 4)
    result += "<clipPath id=\"\(leaf.clipId)\">\n"
    result += "<rect width=\"\(clipW)\" height=\"\(clipH)\" />\n"
    result += "</clipPath>\n"

    if let label = leaf.label, !label.hidden {
        let labelStyle = _textStyle(label, font: font, clipId: leaf.clipId, hidden: false)
        result += "<text class=\"treemapLabel\" x=\"\(w / 2)\" y=\"\(Int(label.y))\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"\(font)\"\(labelStyle)>\(_escapeXml(label.text))</text>\n"
    }

    if let valueText = leaf.valueText, !valueText.hidden {
        let vStyle = _textStyle(valueText, font: font, clipId: leaf.clipId, hidden: false)
        result += "<text class=\"treemapValue\" x=\"\(w / 2)\" y=\"\(Int(valueText.y))\" text-anchor=\"middle\" dominant-baseline=\"hanging\" font-family=\"\(font)\"\(vStyle)>\(_escapeXml(valueText.text))</text>\n"
    }

    result += "</g>\n"

    return result
}

private func _textStyle(_ text: PositionedTreemapText, font: String, clipId: String?, hidden: Bool) -> String {
    var style = ""

    if let fw = text.fontWeight {
        style += " font-weight=\"\(fw)\""
    }
    if let fs = text.fontStyle {
        style += " font-style=\"\(fs)\""
    }
    style += " font-size=\"\(Int(text.fontSize))px\""
    style += " fill=\"\(text.fillColor)\""

    if let cid = clipId {
        style += " clip-path=\"url(#\(cid))\""
    }

    if hidden {
        style += " style=\"display:none\""
    }

    return style
}

private func _escapeXml(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
     .replacingOccurrences(of: "<", with: "&lt;")
     .replacingOccurrences(of: ">", with: "&gt;")
     .replacingOccurrences(of: "\"", with: "&quot;")
     .replacingOccurrences(of: "'", with: "&apos;")
}
