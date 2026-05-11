import Foundation
import DiagramKitCommon

public func renderTreemapSvg(
    _ positioned: PositionedTreemapDiagram,
    diagramId: String,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) -> String {
    var svg = ""

    let padding = max(0, positioned.diagramPadding)
    let viewBoxX = -padding
    let viewBoxY = -padding
    let viewBoxWidth = positioned.svgWidth + padding * 2
    let viewBoxHeight = positioned.svgHeight + padding * 2

    let _builder = SVGDocumentBuilder(
        width: viewBoxWidth, height: viewBoxHeight,
        colors: colors, transparent: transparent,
        fontFamily: font,
        useMaxWidth: positioned.config.useMaxWidth,
        viewBoxX: viewBoxX, viewBoxY: viewBoxY
    )
    svg += _builder.open(className: "treemap", extraAttributes: "id=\"\(_escapeXml(diagramId))\"") + "\n"

    if let accTitle = positioned.accTitle, !accTitle.isEmpty {
        svg += "<title>\(_escapeXml(accTitle))</title>\n"
    }
    if let accDescr = positioned.accDescr, !accDescr.isEmpty {
        svg += "<desc>\(_escapeXml(accDescr))</desc>\n"
    }

    if !transparent {
        svg += "<rect x=\"\(_fmtTreemap(viewBoxX))\" y=\"\(_fmtTreemap(viewBoxY))\" width=\"\(_fmtTreemap(viewBoxWidth))\" height=\"\(_fmtTreemap(viewBoxHeight))\" fill=\"\(_escapeXml(colors.bg))\" />\n"
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

    svg += _builder.close()

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

    let sectionStyle = _styleAttribute(section.cssCompiledStyles, hidden: section.depth == 0)
    result += "<rect class=\"treemapSection section\(section.index)\" width=\"\(w)\" height=\"\(max(0, h))\" fill=\"\(_escapeXml(section.fillColor))\" fill-opacity=\"0.6\" stroke=\"\(_escapeXml(section.strokeColor))\" stroke-width=\"2.0\" stroke-opacity=\"0.4\"\(sectionStyle)/>\n"

    if let label = section.label, !label.hidden {
        let labelStyle = _textStyle(label, font: font, clipId: section.clipId, hidden: section.depth == 0, cssStyles: section.cssCompiledStyles)
        result += "<text class=\"treemapSectionLabel\" x=\"6\" y=\"\(Int(SECTION_HEADER_HEIGHT / 2))\" dominant-baseline=\"middle\" font-weight=\"bold\" font-family=\"\(_escapeXml(font))\"\(labelStyle)>\(_escapeXml(label.text))</text>\n"
    }

    if let value = section.value, !value.hidden, section.depth != 0 {
        let valueStyle = _textStyle(value, font: font, clipId: section.clipId, hidden: false, cssStyles: section.cssCompiledStyles)
        result += "<text class=\"treemapSectionValue\" x=\"\(w - 10)\" y=\"\(Int(SECTION_HEADER_HEIGHT / 2))\" text-anchor=\"end\" dominant-baseline=\"middle\" font-style=\"italic\" font-family=\"\(_escapeXml(font))\"\(valueStyle)>\(_escapeXml(value.text))</text>\n"
    }

    result += "</g>\n"

    return result
}

private func _renderLeafSvg(_ leaf: PositionedTreemapLeaf, font: String) -> String {
    let w = Int(leaf.x1 - leaf.x0)
    let h = Int(leaf.y1 - leaf.y0)

    var classes = "treemapNode treemapLeafGroup leaf\(leaf.index)"
    if let sel = leaf.classSelector { classes += " \(_escapeXml(sel))" }

    var result = ""
    result += "<g class=\"\(classes)\" transform=\"translate(\(Int(leaf.x0)),\(Int(leaf.y0)))\">\n"

    let leafStyle = _styleAttribute(leaf.cssCompiledStyles)
    result += "<rect class=\"treemapLeaf\" width=\"\(w)\" height=\"\(h)\" fill=\"\(_escapeXml(leaf.fillColor))\" fill-opacity=\"0.3\" stroke=\"\(_escapeXml(leaf.strokeColor))\" stroke-width=\"3.0\"\(leafStyle) />\n"

    let clipW = max(0, w - 4)
    let clipH = max(0, h - 4)
    result += "<clipPath id=\"\(leaf.clipId)\">\n"
    result += "<rect width=\"\(clipW)\" height=\"\(clipH)\" />\n"
    result += "</clipPath>\n"

    if let label = leaf.label, !label.hidden {
        let labelStyle = _textStyle(label, font: font, clipId: leaf.clipId, hidden: false, cssStyles: leaf.cssCompiledStyles)
        result += "<text class=\"treemapLabel\" x=\"\(w / 2)\" y=\"\(Int(label.y))\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"\(_escapeXml(font))\"\(labelStyle)>\(_escapeXml(label.text))</text>\n"
    }

    if let valueText = leaf.valueText, !valueText.hidden {
        let vStyle = _textStyle(valueText, font: font, clipId: leaf.clipId, hidden: false, cssStyles: leaf.cssCompiledStyles)
        result += "<text class=\"treemapValue\" x=\"\(w / 2)\" y=\"\(Int(valueText.y))\" text-anchor=\"middle\" dominant-baseline=\"hanging\" font-family=\"\(_escapeXml(font))\"\(vStyle)>\(_escapeXml(valueText.text))</text>\n"
    }

    result += "</g>\n"

    return result
}

private func _textStyle(_ text: PositionedTreemapText, font: String, clipId: String?, hidden: Bool, cssStyles: [String]?) -> String {
    var style = ""

    if let fw = text.fontWeight {
        style += " font-weight=\"\(fw)\""
    }
    if let fs = text.fontStyle {
        style += " font-style=\"\(fs)\""
    }
    style += " font-size=\"\(Int(text.fontSize))px\""
    style += " fill=\"\(_escapeXml(text.fillColor))\""

    if let cid = clipId {
        style += " clip-path=\"url(#\(_escapeXml(cid)))\""
    }

    style += _styleAttribute(cssStyles, hidden: hidden, text: true)

    return style
}

private func _styleAttribute(_ cssStyles: [String]?, hidden: Bool = false, text: Bool = false) -> String {
    var declarations = _treemapStyleDeclarations(cssStyles, text: text)
    if hidden {
        declarations.insert("display:none", at: 0)
    }
    guard !declarations.isEmpty else { return "" }
    return " style=\"\(declarations.map(_escapeXml).joined(separator: ";"))\""
}

private func _fmtTreemap(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }
    return String(format: "%.2f", value)
}

private func _escapeXml(_ s: String) -> String {
    SVG.escapeText(s)
}
