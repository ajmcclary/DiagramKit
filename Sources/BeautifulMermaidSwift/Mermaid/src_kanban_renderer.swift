import Foundation

private let _kanbanThemeColorLimit = 10

public func renderKanbanSvg(
    _ positioned: PositionedKanbanDiagram,
    diagramId: String,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) throws -> String {
    let bgColor = colors.bg
    let fgColor = colors.fg
    let borderColor = colors.border ?? "#a1a1aa"
    let surfaceColor = colors.surface ?? bgColor
    let accentColor = colors.accent ?? borderColor

    let sectionPalette = _kanbanSectionColorPalette(accent: accentColor, limit: _kanbanThemeColorLimit)

    var svg = ""

    let bounds = _kanbanSvgBounds(positioned)
    let viewBoxX = Int(floor(bounds.minX))
    let viewBoxY = Int(floor(bounds.minY))
    let width = max(1, Int(ceil(bounds.maxX)) - viewBoxX)
    let height = max(1, Int(ceil(bounds.maxY)) - viewBoxY)

    svg += "<svg id=\"\(SVG.escapeAttribute(diagramId))\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\""
    if positioned.config.useMaxWidth {
        svg += " width=\"100%\" style=\"max-width: \(width)px;\" viewBox=\"\(viewBoxX) \(viewBoxY) \(width) \(height)\""
    } else {
        svg += " width=\"\(width)\" height=\"\(height)\" viewBox=\"\(viewBoxX) \(viewBoxY) \(width) \(height)\""
    }
    svg += ">\n"

    if let accTitle = positioned.accTitle, !accTitle.isEmpty {
        svg += "<title>\(_escapeXml(accTitle))</title>\n"
    }
    if let accDescr = positioned.accDescr, !accDescr.isEmpty {
        svg += "<desc>\(_escapeXml(accDescr))</desc>\n"
    }

    svg += _kanbanSvgStyleBlock(bg: bgColor, border: borderColor, fg: fgColor, sectionPalette: sectionPalette, limit: _kanbanThemeColorLimit)

    if !transparent {
        svg += "<rect x=\"\(viewBoxX)\" y=\"\(viewBoxY)\" width=\"\(width)\" height=\"\(height)\" fill=\"\(bgColor)\"/>\n"
    }

    svg += "<g class=\"sections\">\n"
    for section in positioned.sections {
        let sx = Int(ceil(section.x - section.width / 2))
        let sy = Int(ceil(_kanbanSectionTop(section)))
        let sw = Int(ceil(section.width))
        let sh = Int(ceil(section.height))
        let sectionClass = section.cssClasses.map { "\($0) section-\(section.sectionIndex)" } ?? "section-\(section.sectionIndex)"

        let paletteIdx = (section.sectionIndex - 1) % _kanbanThemeColorLimit
        let sectionFill = sectionPalette.fill[paletteIdx]
        let sectionStroke = sectionPalette.stroke[paletteIdx]
        let sectionTextFill = sectionPalette.text[paletteIdx]

        svg += "<g id=\"\(SVG.escapeAttribute(diagramId))-\(SVG.escapeAttribute(section.id))\" class=\"cluster \(sectionClass)\">\n"
        svg += "<rect x=\"\(sx)\" y=\"\(sy)\" width=\"\(sw)\" height=\"\(sh)\" rx=\"5\" ry=\"5\" fill=\"\(sectionFill)\" stroke=\"\(sectionStroke)\" stroke-width=\"1\"/>\n"
        svg += "<text x=\"\(Int(ceil(section.x)))\" y=\"\(sy + 25)\" text-anchor=\"middle\" dominant-baseline=\"middle\" fill=\"\(sectionTextFill)\" font-family=\"\(font)\" font-size=\"14\">\(_escapeXml(section.label))</text>\n"
        svg += "</g>\n"
    }
    svg += "</g>\n"

    svg += "<g class=\"items\">\n"
    for card in positioned.cards {
        let cx = Int(ceil(card.x))
        let cy = Int(ceil(card.y))
        let cw = Int(ceil(card.width))
        let ch = Int(ceil(card.height))
        let cardLeft = cx - cw / 2
        let cardTop = cy - ch / 2

        var cardClass = "basic label-container __APA__"
        if let cc = card.cssClasses { cardClass += " \(cc)" }

        svg += "<g id=\"\(SVG.escapeAttribute(diagramId))-\(SVG.escapeAttribute(card.id))\" class=\"node\">\n"

        svg += "<rect class=\"\(cardClass)\" x=\"\(cardLeft)\" y=\"\(cardTop)\" width=\"\(cw)\" height=\"\(ch)\" rx=\"5\" ry=\"5\" fill=\"\(surfaceColor)\" stroke=\"\(borderColor)\" stroke-width=\"1\"/>\n"

        if let stripeColor = _kanbanPriorityColor(card.priority) {
            let lineX = cardLeft + 2
            let y1 = cardTop + Int(floor(card.rx / 2))
            let y2 = cardTop + ch - Int(floor(card.rx / 2))
            svg += "<line x1=\"\(lineX)\" y1=\"\(y1)\" x2=\"\(lineX)\" y2=\"\(y2)\" stroke-width=\"4\" stroke=\"\(stripeColor)\"/>\n"
        }

        let labelX = cardLeft + Int(_kanbanCardTextInset)
        let labelY = cardTop + 16
        let labelLines = _kanbanWrappedLabelLines(
            card.label,
            maxWidth: max(1, Double(cw) - 2 * _kanbanCardTextInset)
        )
        svg += _kanbanSvgLabelText(lines: labelLines, x: labelX, y: labelY, fill: fgColor, font: font)
        let metadataY = labelY + Int(ceil(Double(max(labelLines.count, 1)) * _kanbanCardLabelLineHeight))

        if let ticket = card.ticket {
            let baseUrl = positioned.config.ticketBaseUrl
            if let url = _safeKanbanTicketURL(baseUrl: baseUrl, ticket: ticket) {
                svg += "<a xlink:href=\"\(SVG.escapeAttribute(url))\" class=\"kanban-ticket-link\" target=\"_blank\">\n"
                svg += "<text x=\"\(labelX)\" y=\"\(metadataY)\" text-anchor=\"start\" fill=\"\(accentColor)\" font-family=\"\(font)\" font-size=\"10\" text-decoration=\"underline\">\(_escapeXml(ticket))</text>\n"
                svg += "</a>\n"
            } else {
                svg += "<text x=\"\(labelX)\" y=\"\(metadataY)\" text-anchor=\"start\" fill=\"\(fgColor)\" font-family=\"\(font)\" font-size=\"10\">\(_escapeXml(ticket))</text>\n"
            }
        }

        if let assigned = card.assigned {
            svg += "<text x=\"\(cx + cw / 2 - 10)\" y=\"\(cy + ch / 2 - 8)\" text-anchor=\"end\" fill=\"\(fgColor)\" font-family=\"\(font)\" font-size=\"10\">\(_escapeXml(assigned))</text>\n"
        }

        svg += "</g>\n"
    }
    svg += "</g>\n"

    svg += "</svg>"
    return svg
}

private func _kanbanSvgLabelText(lines: [String], x: Int, y: Int, fill: String, font: String) -> String {
    let lineHeight = Int(ceil(_kanbanCardLabelLineHeight))
    if lines.count <= 1 {
        return "<text x=\"\(x)\" y=\"\(y)\" text-anchor=\"start\" fill=\"\(fill)\" font-family=\"\(font)\" font-size=\"12\" class=\"kanban-label\">\(_escapeXml(lines.first ?? ""))</text>\n"
    }

    var svg = "<text x=\"\(x)\" y=\"\(y)\" text-anchor=\"start\" fill=\"\(fill)\" font-family=\"\(font)\" font-size=\"12\" class=\"kanban-label\">"
    for (index, line) in lines.enumerated() {
        let dy = index == 0 ? 0 : lineHeight
        svg += "<tspan x=\"\(x)\" dy=\"\(dy)\">\(_escapeXml(line))</tspan>"
    }
    svg += "</text>\n"
    return svg
}

// MARK: - Style Block

private struct _KanbanSectionPalette {
    var fill: [String]
    var stroke: [String]
    var text: [String]
}

private func _kanbanSectionColorPalette(accent: String, limit: Int) -> _KanbanSectionPalette {
    let baseColors: [(h: Double, s: Double, l: Double)] = [
        (210, 0.55, 0.85),  // blue
        (170, 0.50, 0.82),  // teal
        (140, 0.48, 0.80),  // green
        (45, 0.50, 0.82),   // amber
        (30, 0.55, 0.80),   // orange
        (0, 0.50, 0.88),    // rose
        (280, 0.45, 0.85),  // violet
        (320, 0.45, 0.85),  // pink
        (195, 0.40, 0.88),  // sky
        (10, 0.45, 0.82),   // coral
    ]

    var fills: [String] = []
    var strokes: [String] = []
    var texts: [String] = []

    for i in 0..<limit {
        let c = baseColors[i % baseColors.count]
        let fillL = c.l + 0.06
        let strokeL = c.l - 0.04
        let textH = c.h
        let textS = c.s * 0.6
        let textL = 0.35
        fills.append(_hslToHex(h: c.h, s: c.s, l: min(fillL, 0.93)))
        strokes.append(_hslToHex(h: c.h, s: c.s, l: max(strokeL, 0.50)))
        texts.append(_hslToHex(h: textH, s: textS, l: textL))
    }

    return _KanbanSectionPalette(fill: fills, stroke: strokes, text: texts)
}

private func _hslToHex(h: Double, s: Double, l: Double) -> String {
    let hue = h / 360.0
    let c = (1 - abs(2 * l - 1)) * s
    let x = c * (1 - abs((hue * 6).truncatingRemainder(dividingBy: 2) - 1))
    let m = l - c / 2

    let (r, g, b): (Double, Double, Double)
    switch Int(hue * 6) {
    case 0: (r, g, b) = (c, x, 0)
    case 1: (r, g, b) = (x, c, 0)
    case 2: (r, g, b) = (0, c, x)
    case 3: (r, g, b) = (0, x, c)
    case 4: (r, g, b) = (x, 0, c)
    default: (r, g, b) = (c, 0, x)
    }

    let ri = Int(round((r + m) * 255))
    let gi = Int(round((g + m) * 255))
    let bi = Int(round((b + m) * 255))

    return String(format: "#%02X%02X%02X", min(max(ri, 0), 255), min(max(gi, 0), 255), min(max(bi, 0), 255))
}

private func _kanbanSvgStyleBlock(bg: String, border: String, fg: String, sectionPalette: _KanbanSectionPalette, limit: Int) -> String {
    var css = "<style>\n"

    css += """
    .node rect,
    .node circle,
    .node ellipse,
    .node polygon,
    .node path {
      fill: \(bg);
      stroke: \(border);
      stroke-width: 1px;
    }
    .kanban-ticket-link {
      fill: \(bg);
      stroke: \(border);
      text-decoration: underline;
    }
    .kanban-label {
      dy: 1em;
      alignment-baseline: middle;
      text-anchor: middle;
      dominant-baseline: middle;
      text-align: left;
    }

    """

    for i in 0..<limit {
        let idx = i + 1
        css += """
        .section-\(idx) rect, .section-\(idx) path, .section-\(idx) circle, .section-\(idx) polygon {
          fill: \(sectionPalette.fill[i]);
          stroke: \(sectionPalette.stroke[i]);
        }
        .section-\(idx) text {
          fill: \(sectionPalette.text[i]);
        }

        """
    }

    css += "</style>\n"
    return css
}

private struct KanbanSvgBounds {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double
}

private func _kanbanSvgBounds(_ positioned: PositionedKanbanDiagram) -> KanbanSvgBounds {
    var minX = Double.infinity
    var minY = Double.infinity
    var maxX = -Double.infinity
    var maxY = -Double.infinity

    func include(x: Double, y: Double, width: Double, height: Double) {
        minX = Swift.min(minX, x)
        minY = Swift.min(minY, y)
        maxX = Swift.max(maxX, x + width)
        maxY = Swift.max(maxY, y + height)
    }

    for section in positioned.sections {
        include(
            x: section.x - section.width / 2,
            y: _kanbanSectionTop(section),
            width: section.width,
            height: section.height
        )
    }

    for card in positioned.cards {
        include(
            x: card.x - card.width / 2,
            y: card.y - card.height / 2,
            width: card.width,
            height: card.height
        )
    }

    if minX == Double.infinity {
        minX = 0
        minY = 0
        maxX = positioned.width
        maxY = positioned.height
    }

    let padding = positioned.config.padding
    return KanbanSvgBounds(
        minX: minX - padding,
        minY: minY - padding,
        maxX: maxX + padding,
        maxY: maxY + padding
    )
}

private func _kanbanSectionTop(_ section: PositionedKanbanSection) -> Double {
    section.y - (section.width * 3) / 2
}

private func _kanbanPriorityColor(_ priority: String?) -> String? {
    switch priority {
    case "Very High": return "red"
    case "High": return "orange"
    case "Medium": return nil
    case "Low": return "blue"
    case "Very Low": return "lightblue"
    default: return nil
    }
}

private func _safeKanbanTicketURL(baseUrl: String, ticket: String) -> String? {
    let trimmed = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let lowered = trimmed.lowercased()
    let dangerousPrefixes = ["javascript:", "data:", "vbscript:", "file:"]
    guard !dangerousPrefixes.contains(where: { lowered.hasPrefix($0) }) else {
        return nil
    }
    return trimmed.replacingOccurrences(of: "#TICKET#", with: ticket)
}

private func _escapeXml(_ text: String) -> String {
    SVG.escapeText(text)
}
