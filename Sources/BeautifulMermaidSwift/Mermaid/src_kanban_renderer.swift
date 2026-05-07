import Foundation

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

    var svg = ""

    let bounds = _kanbanSvgBounds(positioned)
    let viewBoxX = Int(floor(bounds.minX))
    let viewBoxY = Int(floor(bounds.minY))
    let width = max(1, Int(ceil(bounds.maxX)) - viewBoxX)
    let height = max(1, Int(ceil(bounds.maxY)) - viewBoxY)

    svg += "<svg id=\"\(_escapeXml(diagramId))\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\""
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

        svg += "<g id=\"\(_escapeXml(diagramId))-\(_escapeXml(section.id))\" class=\"cluster \(sectionClass)\">\n"
        svg += "<rect x=\"\(sx)\" y=\"\(sy)\" width=\"\(sw)\" height=\"\(sh)\" rx=\"5\" ry=\"5\" fill=\"\(surfaceColor)\" stroke=\"\(borderColor)\" stroke-width=\"1\"/>\n"
        svg += "<text x=\"\(Int(ceil(section.x)))\" y=\"\(sy + 25)\" text-anchor=\"middle\" dominant-baseline=\"middle\" fill=\"\(fgColor)\" font-family=\"\(font)\" font-size=\"14\">\(_escapeXml(section.label))</text>\n"
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

        svg += "<g id=\"\(_escapeXml(diagramId))-\(_escapeXml(card.id))\" class=\"node\">\n"

        svg += "<rect class=\"\(cardClass)\" x=\"\(cardLeft)\" y=\"\(cardTop)\" width=\"\(cw)\" height=\"\(ch)\" rx=\"5\" ry=\"5\" fill=\"\(surfaceColor)\" stroke=\"\(borderColor)\" stroke-width=\"1\"/>\n"

        if let stripeColor = _kanbanPriorityColor(card.priority) {
            let lineX = cardLeft + 2
            let y1 = cardTop + Int(floor(card.rx / 2))
            let y2 = cardTop + ch - Int(floor(card.rx / 2))
            svg += "<line x1=\"\(lineX)\" y1=\"\(y1)\" x2=\"\(lineX)\" y2=\"\(y2)\" stroke-width=\"4\" stroke=\"\(stripeColor)\"/>\n"
        }

        svg += "<text x=\"\(cardLeft + 10)\" y=\"\(cardTop + 16)\" text-anchor=\"start\" fill=\"\(fgColor)\" font-family=\"\(font)\" font-size=\"12\" style=\"text-align:left\">\(_escapeXml(card.label))</text>\n"

        if let ticket = card.ticket {
            let baseUrl = positioned.config.ticketBaseUrl
            if let url = _safeKanbanTicketURL(baseUrl: baseUrl, ticket: ticket) {
                svg += "<a xlink:href=\"\(_escapeXml(url))\" class=\"kanban-ticket-link\" target=\"_blank\">\n"
                svg += "<text x=\"\(cardLeft + 10)\" y=\"\(cardTop + 30)\" text-anchor=\"start\" fill=\"\(accentColor)\" font-family=\"\(font)\" font-size=\"10\" text-decoration=\"underline\">\(_escapeXml(ticket))</text>\n"
                svg += "</a>\n"
            } else {
                svg += "<text x=\"\(cardLeft + 10)\" y=\"\(cardTop + 30)\" text-anchor=\"start\" fill=\"\(fgColor)\" font-family=\"\(font)\" font-size=\"10\">\(_escapeXml(ticket))</text>\n"
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
    return text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}
