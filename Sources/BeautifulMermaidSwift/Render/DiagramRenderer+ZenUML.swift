import Foundation
import CoreGraphics

// MARK: - ZenUML Core Graphics Renderer

extension DiagramRenderer {
    func _drawZenUML(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .zenuml(diagram) = positioned.content else { return }

        let fgColor = theme.foreground
        let lineCG = theme.effectiveLine().cgColor
        let surfaceCG = theme.effectiveSurface().cgColor
        let mutedCG = theme.effectiveMuted().cgColor
        let borderCG = theme.effectiveBorder().cgColor
        let bgCG = theme.background.cgColor

        _withFittedContext(context, bounds: bounds, contentWidth: diagram.width, contentHeight: diagram.height) { ctx in
            // Draw groups behind lifelines and participants
            for group in diagram.groups {
                _drawZenUMLGroup(group, lineColor: lineCG, fgColor: fgColor, in: ctx)
            }

            // Draw lifelines (behind participants)
            for lifeline in diagram.lifelines {
                _drawZenUMLLifeline(lifeline, lineColor: lineCG, in: ctx)
            }

            // Draw occurrences (activation boxes)
            for occurrence in diagram.occurrences {
                _drawZenUMLOccurrence(occurrence, surfaceColor: surfaceCG, lineColor: lineCG, in: ctx)
            }

            // Draw participants
            for participant in diagram.participants {
                _drawZenUMLParticipant(participant, bgColor: bgCG, lineColor: lineCG, fgColor: fgColor, in: ctx)
            }

            // Draw messages
            for message in diagram.messages {
                _drawZenUMLMessage(message, fgColor: fgColor, in: ctx)
            }

            // Draw self-calls
            for selfCall in diagram.selfCalls {
                _drawZenUMLSelfCall(selfCall, fgColor: fgColor, in: ctx)
            }

            // Draw creations
            for creation in diagram.creations {
                _drawZenUMLCreation(creation, bgColor: bgCG, lineColor: lineCG, fgColor: fgColor, in: ctx)
            }

            // Draw fragments (on top)
            for fragment in diagram.fragments {
                _drawZenUMLFragment(fragment, lineColor: lineCG, mutedColor: mutedCG, fgColor: fgColor, in: ctx)
            }

            // Draw returns
            for ret in diagram.returns {
                _drawZenUMLReturn(ret, fgColor: fgColor, in: ctx)
            }

            // Draw dividers
            for divider in diagram.dividers {
                _drawZenUMLDivider(divider, surfaceColor: surfaceCG, borderColor: borderCG, fgColor: fgColor, in: ctx)
            }

            // Draw comments
            for comment in diagram.comments {
                _drawZenUMLComment(comment, fgColor: fgColor, in: ctx)
            }

            // Draw title
            if let title = diagram.title {
                _drawTextInFlipped(title, at: CGPoint(x: diagram.width / 2, y: 14), context: ctx, contentHeight: diagram.height, color: fgColor, font: _monoFont(size: 16))
            }
        }
    }

    private func _drawZenUMLParticipant(
        _ p: PositionedZenUMLParticipant,
        bgColor: CGColor, lineColor: CGColor, fgColor: BMColor,
        in context: CGContext
    ) {
        let rect = CGRect(x: p.x - p.width / 2, y: p.y, width: p.width, height: p.height)
        let roundedPath = CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil)

        context.saveGState()
        context.setFillColor(bgColor)
        context.setStrokeColor(lineColor)
        context.setLineWidth(2)
        context.addPath(roundedPath)
        context.fillPath()
        context.addPath(roundedPath)
        context.strokePath()

        _drawTextInFlipped(p.label, at: CGPoint(x: p.x, y: rect.midY), context: context, contentHeight: p.height, color: fgColor, font: _monoFont(size: 16))
        context.restoreGState()
    }

    private func _drawZenUMLLifeline(_ l: PositionedZenUMLLifeline, lineColor: CGColor, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(lineColor)
        context.setLineWidth(1)

        if l.dashed {
            context.setLineDash(phase: 0, lengths: [5, 5])
        }

        context.move(to: CGPoint(x: l.x, y: l.topY))
        context.addLine(to: CGPoint(x: l.x, y: l.bottomY))
        context.strokePath()
        context.restoreGState()
    }

    private func _drawZenUMLMessage(_ m: PositionedZenUMLMessage, fgColor: BMColor, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(fgColor.cgColor)
        context.setLineWidth(2)

        if m.isSelf {
            let ux = max(0, m.fromX) - 20
            let uw: CGFloat = 40
            let uh: CGFloat = 25
            context.move(to: CGPoint(x: ux, y: m.y))
            context.addLine(to: CGPoint(x: ux, y: m.y + uh))
            context.addLine(to: CGPoint(x: ux + uw, y: m.y + uh))
            context.addLine(to: CGPoint(x: ux + uw, y: m.y))
            context.strokePath()

            _drawTextInFlipped(m.label, at: CGPoint(x: ux + uw / 2, y: m.y + uh / 2), context: context, contentHeight: uh, color: fgColor, font: _monoFont(size: 14))
        } else {
            let isReverse = m.isReverse
            let fromX = m.fromX + (isReverse ? -10 : 10)
            let toX = m.toX + (isReverse ? 10 : -10)
            let arrowSize: CGFloat = 8

            context.move(to: CGPoint(x: fromX, y: m.y))
            context.addLine(to: CGPoint(x: toX, y: m.y))
            context.strokePath()

            let ax = isReverse ? toX + arrowSize : toX - arrowSize
            if m.arrowStyle == .open {
                context.move(to: CGPoint(x: toX, y: m.y))
                context.addLine(to: CGPoint(x: ax, y: m.y - arrowSize / 2))
                context.strokePath()
                context.move(to: CGPoint(x: toX, y: m.y))
                context.addLine(to: CGPoint(x: ax, y: m.y + arrowSize / 2))
                context.strokePath()
            } else {
                context.setFillColor(fgColor.cgColor)
                context.move(to: CGPoint(x: toX, y: m.y))
                context.addLine(to: CGPoint(x: ax, y: m.y - arrowSize / 2))
                context.addLine(to: CGPoint(x: ax, y: m.y + arrowSize / 2))
                context.closePath()
                context.fillPath()
            }

            let midX = (fromX + toX) / 2
            _drawTextInFlipped(m.label, at: CGPoint(x: midX, y: m.y - 8), context: context, contentHeight: 16, color: fgColor, font: _monoFont(size: 14))
        }

        context.restoreGState()
    }

    private func _drawZenUMLFragment(
        _ f: PositionedZenUMLFragment,
        lineColor: CGColor, mutedColor: CGColor, fgColor: BMColor,
        in context: CGContext
    ) {
        let headerHeight: CGFloat = 25
        let rect = CGRect(x: f.x, y: f.y, width: f.width, height: f.height)

        context.saveGState()

        context.setStrokeColor(lineColor)
        context.setLineWidth(1)
        context.stroke(rect)

        context.setFillColor(mutedColor)
        context.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: headerHeight))

        let label = "\(f.kind.rawValue) [\(f.label)]"
        _drawTextInFlipped(label, at: CGPoint(x: rect.minX + 10, y: rect.minY + headerHeight / 2), context: context, contentHeight: headerHeight, color: fgColor, font: _monoFont(size: 14))

        context.restoreGState()
    }

    private func _drawZenUMLReturn(_ r: PositionedZenUMLReturn, fgColor: BMColor, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(fgColor.cgColor)
        context.setLineWidth(2)
        context.setLineDash(phase: 0, lengths: [6, 4])

        let isReverse = r.isReverse
        let fromX = r.fromX + (isReverse ? -10 : 10)
        let toX = r.toX + (isReverse ? 10 : -10)
        let arrowSize: CGFloat = 8

        context.move(to: CGPoint(x: fromX, y: r.y))
        context.addLine(to: CGPoint(x: toX, y: r.y))
        context.strokePath()

        context.setLineDash(phase: 0, lengths: [])
        let ax = isReverse ? toX + arrowSize : toX - arrowSize
        context.move(to: CGPoint(x: toX, y: r.y))
        context.addLine(to: CGPoint(x: ax, y: r.y - arrowSize / 2))
        context.strokePath()
        context.move(to: CGPoint(x: toX, y: r.y))
        context.addLine(to: CGPoint(x: ax, y: r.y + arrowSize / 2))
        context.strokePath()

        context.restoreGState()
    }

    private func _drawZenUMLOccurrence(
        _ o: PositionedZenUMLOccurrence,
        surfaceColor: CGColor, lineColor: CGColor,
        in context: CGContext
    ) {
        context.saveGState()
        context.setFillColor(surfaceColor)
        context.setStrokeColor(lineColor)
        context.setLineWidth(2)
        let rect = CGRect(x: o.x, y: o.y, width: o.width, height: o.height)
        context.fill(rect)
        context.stroke(rect)
        context.restoreGState()
    }

    private func _drawZenUMLSelfCall(_ sc: PositionedZenUMLSelfCall, fgColor: BMColor, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(fgColor.cgColor)
        context.setLineWidth(2)
        let ux = sc.x; let uy = sc.y; let uw = sc.width; let uh = sc.height
        context.move(to: CGPoint(x: ux, y: uy))
        context.addLine(to: CGPoint(x: ux, y: uy + uh))
        context.addLine(to: CGPoint(x: ux + uw, y: uy + uh))
        context.addLine(to: CGPoint(x: ux + uw, y: uy))
        context.strokePath()
        let arrowSize: CGFloat = 8
        if sc.arrowStyle == .open {
            context.move(to: CGPoint(x: ux + uw, y: uy))
            context.addLine(to: CGPoint(x: ux + uw + arrowSize, y: uy - arrowSize / 2))
            context.strokePath()
            context.move(to: CGPoint(x: ux + uw, y: uy))
            context.addLine(to: CGPoint(x: ux + uw + arrowSize, y: uy + arrowSize / 2))
            context.strokePath()
        } else {
            context.setFillColor(fgColor.cgColor)
            context.move(to: CGPoint(x: ux + uw, y: uy))
            context.addLine(to: CGPoint(x: ux + uw + arrowSize, y: uy - arrowSize / 2))
            context.addLine(to: CGPoint(x: ux + uw + arrowSize, y: uy + arrowSize / 2))
            context.closePath()
            context.fillPath()
        }
        _drawTextInFlipped(sc.label, at: CGPoint(x: ux + uw / 2, y: uy + uh / 2), context: context, contentHeight: uh, color: fgColor, font: _monoFont(size: 14))
        context.restoreGState()
    }

    private func _drawZenUMLCreation(
        _ c: PositionedZenUMLCreation,
        bgColor: CGColor, lineColor: CGColor, fgColor: BMColor,
        in context: CGContext
    ) {
        let p = c.participant
        let m = c.message
        _drawZenUMLParticipant(p, bgColor: bgColor, lineColor: lineColor, fgColor: fgColor, in: context)
        context.saveGState()
        context.setStrokeColor(fgColor.cgColor)
        context.setLineWidth(2)
        context.setLineDash(phase: 0, lengths: [6, 4])
        context.move(to: CGPoint(x: m.fromX, y: m.y))
        context.addLine(to: CGPoint(x: m.toX, y: m.y))
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
        let ax: CGFloat = m.toX - 8
        context.move(to: CGPoint(x: m.toX, y: m.y))
        context.addLine(to: CGPoint(x: ax, y: m.y - 4))
        context.strokePath()
        context.move(to: CGPoint(x: m.toX, y: m.y))
        context.addLine(to: CGPoint(x: ax, y: m.y + 4))
        context.strokePath()
        let midX = (m.fromX + m.toX) / 2
        _drawTextInFlipped(m.label, at: CGPoint(x: midX, y: m.y - 8), context: context, contentHeight: 16, color: fgColor, font: _monoFont(size: 14))
        context.restoreGState()
    }

    private func _drawZenUMLDivider(
        _ d: PositionedZenUMLDivider,
        surfaceColor: CGColor, borderColor: CGColor, fgColor: BMColor,
        in context: CGContext
    ) {
        let bgHeight: CGFloat = 24
        let rect = CGRect(x: 0, y: d.y - bgHeight / 2, width: d.width, height: bgHeight)

        context.saveGState()
        context.setFillColor(surfaceColor)
        context.setStrokeColor(borderColor)
        context.setLineWidth(1)
        context.fill(rect)
        context.stroke(rect)

        if !d.label.isEmpty {
            _drawTextInFlipped(d.label, at: CGPoint(x: d.width / 2, y: d.y), context: context, contentHeight: bgHeight, color: fgColor, font: _monoFont(size: 14))
        }

        context.restoreGState()
    }

    private func _drawZenUMLGroup(_ g: PositionedZenUMLGroup, lineColor: CGColor, fgColor: BMColor, in context: CGContext) {
        let rect = CGRect(x: g.x, y: g.y, width: g.width, height: g.height)

        context.saveGState()
        context.setStrokeColor(lineColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [5, 5])
        context.stroke(rect)
        context.setLineDash(phase: 0, lengths: [])

        if !g.name.isEmpty {
            _drawTextInFlipped(g.name, at: CGPoint(x: rect.minX + 5, y: max(10, rect.minY - 5)), context: context, contentHeight: 14, color: fgColor, font: _monoFont(size: 13))
        }

        context.restoreGState()
    }

    private func _drawZenUMLComment(_ comment: PositionedZenUMLComment, fgColor: BMColor, in context: CGContext) {
        _drawTextInFlipped(comment.text, at: CGPoint(x: comment.x, y: comment.y), context: context, contentHeight: 16, color: fgColor, font: _italicMonoFont(size: 13))
    }
}
