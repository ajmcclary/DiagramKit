import Foundation

public let _kanbanItemGap = 10.0
public let _kanbanCardTextInset = 10.0
public let _kanbanCardLabelFontSize = 12.0
public let _kanbanCardLabelLineHeight = 16.0

private let _kanbanMinimumHeaderHeight = 45.0
private let _kanbanCardBaseHeight = 30.0
private let _kanbanCardMetadataHeight = 20.0
private let _kanbanApproximateCharacterWidthRatio = 0.58

public func layoutKanbanDiagram(_ diagram: KanbanDiagram) -> PositionedKanbanDiagram {
    let config = diagram.config
    let sectionWidth = config.sectionWidth
    let itemGap = _kanbanItemGap

    guard !diagram.sections.isEmpty else {
        return .empty
    }

    var maxLabelHeight = 25.0
    var sectionObjects: [(section: KanbanNode, idx: Int)] = []

    for (idx, section) in diagram.sections.enumerated() {
        sectionObjects.append((section: section, idx: idx))
        maxLabelHeight = max(maxLabelHeight, _measureKanbanLabelHeight(section.label))
    }

    var positionedSections: [PositionedKanbanSection] = []
    var positionedCards: [PositionedKanbanCard] = []

    for (objIdx, so) in sectionObjects.enumerated() {
        let sectionIdx = objIdx + 1
        let x = sectionWidth * Double(sectionIdx) + (Double(sectionIdx - 1) * itemGap) / 2
        let sectionTop = (-sectionWidth * 3) / 2
        let headerHeight = max(_kanbanMinimumHeaderHeight, maxLabelHeight + 2 * itemGap)
        let contentTop = sectionTop + headerHeight
        var y = contentTop
        let section = so.section
        var cardRects: [(id: String, y: Double, height: Double)] = []
        let cardWidth = sectionWidth - 1.5 * itemGap
        let cardLabelWidth = max(1, cardWidth - 2 * _kanbanCardTextInset)

        let sectionCards = diagram.nodes.filter { $0.parentId == section.id && !$0.isGroup }
        for card in sectionCards {
            let cardHeight = _measureKanbanCardHeight(card, maxLabelWidth: cardLabelWidth)
            let cardY = y + cardHeight / 2
            cardRects.append((id: card.id, y: cardY, height: cardHeight))
            y = cardY + cardHeight / 2 + itemGap / 2
        }

        let sectionHeight = max(y - sectionTop + 2 * itemGap, headerHeight + 2 * itemGap)

        positionedSections.append(PositionedKanbanSection(
            id: section.id,
            label: section.label,
            x: x,
            y: 0,
            width: sectionWidth,
            height: sectionHeight,
            rx: 5,
            ry: 5,
            sectionIndex: sectionIdx,
            cssClasses: section.cssClasses,
            icon: section.icon
        ))

        for card in sectionCards {
            if let rect = cardRects.first(where: { $0.id == card.id }) {
                positionedCards.append(PositionedKanbanCard(
                    id: card.id,
                    label: card.label,
                    parentSectionId: section.id,
                    x: x,
                    y: rect.y,
                    width: cardWidth,
                    height: rect.height,
                    rx: 5,
                    ry: 5,
                    ticket: card.ticket,
                    assigned: card.assigned,
                    priority: card.priority,
                    icon: card.icon,
                    cssClasses: card.cssClasses
                ))
            }
        }
    }

    let maxSectionRight = positionedSections.map { $0.x + $0.width / 2 }.max() ?? sectionWidth
    let maxSectionBottom = positionedSections.map { $0.y + $0.height }.max() ?? sectionWidth * 3
    let maxCardBottom = positionedCards.map { $0.y + $0.height / 2 }.max() ?? maxSectionBottom
    let contentBottom = max(maxSectionBottom, maxCardBottom)
    let totalWidth = maxSectionRight + config.padding * 2
    let totalHeight = contentBottom + config.padding * 2

    return PositionedKanbanDiagram(
        width: totalWidth,
        height: totalHeight,
        sections: positionedSections,
        cards: positionedCards,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        diagramTitle: diagram.diagramTitle,
        config: config
    )
}

private func _measureKanbanLabelHeight(_ label: String) -> Double {
    let baseLines = max(1, label.components(separatedBy: "\n").count)
    return Double(baseLines) * 16 + 4
}

private func _measureKanbanCardHeight(_ card: KanbanNode, maxLabelWidth: Double) -> Double {
    var height = _kanbanCardBaseHeight
    let labelLines = max(1, _kanbanWrappedLabelLines(card.label, maxWidth: maxLabelWidth).count)
    height += Double(labelLines) * _kanbanCardLabelLineHeight
    if card.ticket != nil || card.assigned != nil {
        height += _kanbanCardMetadataHeight
    }
    return height
}

public func _kanbanWrappedLabelLines(_ label: String, maxWidth: Double) -> [String] {
    let characterWidth = max(1, _kanbanCardLabelFontSize * _kanbanApproximateCharacterWidthRatio)
    let maxCharacters = max(1, Int(floor(maxWidth / characterWidth)))
    let rawLines = label
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .components(separatedBy: "\n")

    let lines = rawLines.flatMap { _wrapKanbanLine($0, maxCharacters: maxCharacters) }
    return lines.isEmpty ? [""] : lines
}

private func _wrapKanbanLine(_ line: String, maxCharacters: Int) -> [String] {
    let words = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    guard !words.isEmpty else { return [""] }

    var lines: [String] = []
    var current = ""

    for word in words {
        if word.count > maxCharacters {
            if !current.isEmpty {
                lines.append(current)
                current = ""
            }
            let chunks = _splitKanbanWord(word, maxCharacters: maxCharacters)
            if chunks.count > 1 {
                lines.append(contentsOf: chunks.dropLast())
            }
            current = chunks.last ?? ""
            continue
        }

        if current.isEmpty {
            current = word
        } else if current.count + 1 + word.count <= maxCharacters {
            current += " " + word
        } else {
            lines.append(current)
            current = word
        }
    }

    if !current.isEmpty {
        lines.append(current)
    }

    return lines.isEmpty ? [""] : lines
}

private func _splitKanbanWord(_ word: String, maxCharacters: Int) -> [String] {
    var chunks: [String] = []
    var remaining = word

    while remaining.count > maxCharacters {
        let splitIndex = remaining.index(remaining.startIndex, offsetBy: maxCharacters)
        chunks.append(String(remaining[..<splitIndex]))
        remaining = String(remaining[splitIndex...])
    }

    if !remaining.isEmpty {
        chunks.append(remaining)
    }

    return chunks
}
