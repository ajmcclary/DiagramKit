import Foundation

public func layoutKanbanDiagram(_ diagram: KanbanDiagram) -> PositionedKanbanDiagram {
    let config = diagram.config
    let sectionWidth = config.sectionWidth
    let itemGap = 10.0

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
        let top = (-sectionWidth * 3) / 2 + maxLabelHeight
        var y = top
        let section = so.section
        var cardRects: [(id: String, y: Double, height: Double)] = []

        let sectionCards = diagram.nodes.filter { $0.parentId == section.id && !$0.isGroup }
        for card in sectionCards {
            let cardHeight = _measureKanbanCardHeight(card)
            let cardY = y + cardHeight / 2
            cardRects.append((id: card.id, y: cardY, height: cardHeight))
            y = cardY + cardHeight / 2 + itemGap / 2
        }

        let sectionHeight = max(y - top + 3 * itemGap, 50) + (maxLabelHeight - 25)

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
                let cardWidth = sectionWidth - 1.5 * itemGap
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

private func _measureKanbanCardHeight(_ card: KanbanNode) -> Double {
    var height = 30.0
    let labelLines = max(1, card.label.components(separatedBy: "\n").count)
    height += Double(labelLines) * 16
    if card.ticket != nil || card.assigned != nil {
        height += 20
    }
    return height
}
