import Foundation
import DiagramKitModel
import CoreGraphics
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension DiagramRenderer {
    func _drawKanban(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .kanban(data) = positioned.content else { return }

        if !theme.transparent {
            context.setFillColor(theme.background.cgColor)
            context.fill(bounds)
        }

        let renderBounds = _kanbanRenderBounds(data)
        let bw = Double(renderBounds.width)
        let bh = Double(renderBounds.height)
        guard bw > 0, bh > 0 else { return }

        let scale = min(bounds.width / CGFloat(bw), bounds.height / CGFloat(bh))
        let ox = bounds.minX + (bounds.width - CGFloat(bw) * scale) / 2
        let oy = bounds.minY + (bounds.height - CGFloat(bh) * scale) / 2

        context.saveGState()
        context.translateBy(x: ox, y: oy)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -renderBounds.minX, y: -renderBounds.minY)

        let surfaceColor = theme.surface ?? theme.background
        let borderColor = theme.border ?? BMColor(hex: "#a1a1aa")
        let accentColor = theme.accent ?? borderColor

        for section in data.sections {
            let rect = CGRect(
                x: CGFloat(section.x - section.width / 2),
                y: CGFloat(_kanbanSectionTop(section)),
                width: CGFloat(section.width),
                height: CGFloat(section.height)
            )
            let path = CGPath(roundedRect: rect, cornerWidth: CGFloat(section.rx), cornerHeight: CGFloat(section.ry), transform: nil)
            context.addPath(path)
            context.setFillColor(surfaceColor.cgColor)
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(1)
            context.drawPath(using: .fillStroke)

            _drawTextInFlipped(
                section.label,
                at: CGPoint(x: CGFloat(section.x), y: CGFloat(_kanbanSectionTop(section)) + 25),
                context: context,
                contentHeight: CGFloat(bh),
                color: theme.foreground,
                font: _kanbanFont(size: 14),
                alignment: .center
            )
        }

        for card in data.cards {
            let cardRect = CGRect(
                x: CGFloat(card.x - card.width / 2),
                y: CGFloat(card.y - card.height / 2),
                width: CGFloat(card.width),
                height: CGFloat(card.height)
            )

            let path = CGPath(roundedRect: cardRect, cornerWidth: CGFloat(card.rx), cornerHeight: CGFloat(card.ry), transform: nil)
            context.addPath(path)
            context.setFillColor(surfaceColor.cgColor)
            context.setStrokeColor(borderColor.cgColor)
            context.setLineWidth(1)
            context.drawPath(using: .fillStroke)

            if let stripeColor = _kanbanPriorityColor(card.priority) {
                context.setStrokeColor(stripeColor)
                context.setLineWidth(4)
                let lineX = cardRect.minX + 2
                context.move(to: CGPoint(x: lineX, y: cardRect.minY + CGFloat(card.rx / 2)))
                context.addLine(to: CGPoint(x: lineX, y: cardRect.maxY - CGFloat(card.rx / 2)))
                context.strokePath()
            }

            let cardLabelLines = _kanbanWrappedLabelLines(
                card.label,
                maxWidth: max(1, card.width - 2 * _kanbanCardTextInset)
            )
            _drawKanbanLabelLines(
                cardLabelLines,
                in: cardRect,
                context: context,
                contentHeight: CGFloat(bh),
                color: theme.foreground,
                font: _kanbanFont(size: 12)
            )
            let metadataY = cardRect.minY + 16 + CGFloat(max(cardLabelLines.count, 1)) * CGFloat(_kanbanCardLabelLineHeight)

            if let ticket = card.ticket {
                _drawTextInFlipped(
                    ticket,
                    at: CGPoint(x: cardRect.minX + CGFloat(_kanbanCardTextInset), y: metadataY),
                    context: context,
                    contentHeight: CGFloat(bh),
                    color: accentColor,
                    font: _kanbanFont(size: 10),
                    alignment: .left
                )
            }

            if let assigned = card.assigned {
                _drawTextInFlipped(
                    assigned,
                    at: CGPoint(x: CGFloat(card.x + card.width / 2) - 10, y: CGFloat(card.y + card.height / 2) - 8),
                    context: context,
                    contentHeight: CGFloat(bh),
                    color: theme.foreground,
                    font: _kanbanFont(size: 10),
                    alignment: .right
                )
            }
        }

        context.restoreGState()
    }

    private func _kanbanFont(size: CGFloat) -> BMFont {
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        return UIFont.systemFont(ofSize: size)
        #elseif canImport(AppKit)
        return NSFont.systemFont(ofSize: size)
        #endif
    }

    private func _drawKanbanLabelLines(
        _ lines: [String],
        in cardRect: CGRect,
        context: CGContext,
        contentHeight: CGFloat,
        color: BMColor,
        font: BMFont
    ) {
        let clipRect = cardRect.insetBy(dx: CGFloat(_kanbanCardTextInset), dy: 6)

        context.saveGState()
        context.clip(to: clipRect)
        for (index, line) in lines.enumerated() {
            _drawTextInFlipped(
                line,
                at: CGPoint(
                    x: clipRect.minX,
                    y: cardRect.minY + 16 + CGFloat(index) * CGFloat(_kanbanCardLabelLineHeight)
                ),
                context: context,
                contentHeight: contentHeight,
                color: color,
                font: font,
                alignment: .left
            )
        }
        context.restoreGState()
    }

    private func _kanbanPriorityColor(_ priority: String?) -> CGColor? {
        switch priority {
        case "Very High": return CGColor(red: 1, green: 0, blue: 0, alpha: 1)
        case "High": return CGColor(red: 1, green: 0.5, blue: 0, alpha: 1)
        case "Medium": return nil
        case "Low": return CGColor(red: 0, green: 0, blue: 1, alpha: 1)
        case "Very Low": return CGColor(red: 0.68, green: 0.85, blue: 0.9, alpha: 1)
        default: return nil
        }
    }

    private func _kanbanSectionTop(_ section: PositionedKanbanSection) -> Double {
        section.y - (section.width * 3) / 2
    }

    private func _kanbanRenderBounds(_ data: PositionedKanbanDiagram) -> CGRect {
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity

        func include(_ rect: CGRect) {
            minX = Swift.min(minX, rect.minX)
            minY = Swift.min(minY, rect.minY)
            maxX = Swift.max(maxX, rect.maxX)
            maxY = Swift.max(maxY, rect.maxY)
        }

        for section in data.sections {
            include(CGRect(
                x: CGFloat(section.x - section.width / 2),
                y: CGFloat(_kanbanSectionTop(section)),
                width: CGFloat(section.width),
                height: CGFloat(section.height)
            ))
        }

        for card in data.cards {
            include(CGRect(
                x: CGFloat(card.x - card.width / 2),
                y: CGFloat(card.y - card.height / 2),
                width: CGFloat(card.width),
                height: CGFloat(card.height)
            ))
        }

        if minX == CGFloat.infinity {
            return CGRect(x: 0, y: 0, width: max(CGFloat(data.width), 1), height: max(CGFloat(data.height), 1))
        }

        let padding = CGFloat(data.config.padding)
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + 2 * padding,
            height: maxY - minY + 2 * padding
        )
    }
}
