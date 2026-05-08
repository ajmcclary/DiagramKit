import Foundation

func renderPacketSvg(
    _ diagram: PositionedPacketDiagram,
    _ colors: DiagramColors,
    _ fontFamily: String,
    _ transparent: Bool,
    theme: PacketThemeConfig = .default
) -> String {
    let config = diagram.config
    let svgWidth = diagram.width
    let svgHeight = diagram.height

    var svg = ""

    // Root SVG element
    svg += "<svg xmlns=\"http://www.w3.org/2000/svg\""

    if config.useMaxWidth {
        svg += " width=\"100%\""
        svg += " style=\"max-width: \(svgWidth)px;\""
        svg += " viewBox=\"0 0 \(svgWidth) \(svgHeight)\""
    } else {
        svg += " width=\"\(svgWidth)\""
        svg += " height=\"\(svgHeight)\""
        svg += " viewBox=\"0 0 \(svgWidth) \(svgHeight)\""
    }
    svg += ">\n"

    // Accessibility
    if let accTitle = diagram.accTitle, !accTitle.isEmpty {
        svg += "<title>\(accTitle.escapedXML)</title>\n"
    }
    if let accDescr = diagram.accDescr, !accDescr.isEmpty {
        svg += "<desc>\(accDescr.escapedXML)</desc>\n"
    }

    // Background
    if !transparent {
        svg += "<rect width=\"100%\" height=\"100%\" fill=\"\(colors.bg)\"/>\n"
    }

    // CSS styles
    svg += """
    <style>
    .packetByte { font-size: \(theme.byteFontSize); }
    .packetByte.start { fill: \(theme.startByteColor); }
    .packetByte.end { fill: \(theme.endByteColor); }
    .packetLabel { fill: \(theme.labelColor); font-size: \(theme.labelFontSize); }
    .packetTitle { fill: \(theme.titleColor); font-size: \(theme.titleFontSize); }
    .packetBlock { stroke: \(theme.blockStrokeColor); stroke-width: \(theme.blockStrokeWidth); fill: \(theme.blockFillColor); }
    </style>
    """

    // Render each row
    for row in diagram.rows {
        svg += "<g>\n"
        for block in row {
            // Block rectangle
            svg += "<rect x=\"\(block.x)\" y=\"\(block.y)\" width=\"\(block.width)\" height=\"\(block.height)\" class=\"packetBlock\"/>\n"

            // Label (centered)
            let labelX = block.x + block.width / 2
            let labelY = block.y + block.height / 2
            svg += "<text x=\"\(labelX)\" y=\"\(labelY)\" class=\"packetLabel\" dominant-baseline=\"middle\" text-anchor=\"middle\">\(block.label.escapedXML)</text>\n"

            // Bit numbers (if showBits)
            if config.showBits {
                if block.start == block.end {
                    // Single-bit: center
                    let bitX = block.x + block.width / 2
                    let bitY = block.y - 2
                    svg += "<text x=\"\(bitX)\" y=\"\(bitY)\" class=\"packetByte start\" dominant-baseline=\"auto\" text-anchor=\"middle\">\(block.start)</text>\n"
                } else {
                    // Start byte label
                    let startX = block.x
                    let bitY = block.y - 2
                    svg += "<text x=\"\(startX)\" y=\"\(bitY)\" class=\"packetByte start\" dominant-baseline=\"auto\" text-anchor=\"start\">\(block.start)</text>\n"
                    // End byte label
                    let endX = block.x + block.width
                    svg += "<text x=\"\(endX)\" y=\"\(bitY)\" class=\"packetByte end\" dominant-baseline=\"auto\" text-anchor=\"end\">\(block.end)</text>\n"
                }
            }
        }
        svg += "</g>\n"
    }

    // Title at bottom
    if let title = diagram.diagramTitle, !title.isEmpty {
        let effectivePaddingY = config.paddingY + (config.showBits ? 10 : 0)
        let rowHeightTotal = config.rowHeight + effectivePaddingY
        let titleX = svgWidth / 2
        let titleY = svgHeight - rowHeightTotal / 2
        svg += "<text x=\"\(titleX)\" y=\"\(titleY)\" class=\"packetTitle\" dominant-baseline=\"middle\" text-anchor=\"middle\">\(title.escapedXML)</text>\n"
    }

    svg += "</svg>"
    return svg
}
