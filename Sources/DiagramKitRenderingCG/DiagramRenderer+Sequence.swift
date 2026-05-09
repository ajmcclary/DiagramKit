// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import CoreGraphics

extension DiagramRenderer {

    func _drawSequence(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard
            let actors = positioned.sequenceActors,
            let messages = positioned.sequenceMessages,
            !actors.isEmpty
        else { return }

        let blocks = positioned.sequenceBlocks ?? []
        let lifelines = positioned.seqLifelines
        let activations = positioned.seqActivations
        let notes = positioned.seqNotes
        let boxes = positioned.seqBoxes
        let rectHighlights = positioned.seqRectHighlights
        let bottomActors = positioned.seqBottomActors
        let diagramTitle = positioned.seqTitle

        _withFittedContext(context, bounds: bounds, contentWidth: max(1, positioned.width), contentHeight: max(1, positioned.height)) { ctx in
            let ch = max(1, positioned.height)
            let cfg = self.config
            let theme = self.theme

            // Title
            if let title = diagramTitle, !title.isEmpty {
                self._drawTextInFlipped(
                    title,
                    at: CGPoint(x: positioned.width / 2, y: 16),
                    context: ctx, contentHeight: ch,
                    color: theme.foreground,
                    font: BMFont.systemFont(ofSize: 16, weight: .semibold),
                    alignment: .center
                )
            }

            // 0. Rect background highlights (behind everything)
            for rect in rectHighlights {
                let r = CGRect(x: rect.x, y: rect.y, width: max(0, rect.width), height: max(0, rect.height))
                let color = _parseCSSColor(rect.fill) ?? theme.effectiveSurface().cgColor.copy(alpha: 0.15)!
                ctx.setFillColor(color)
                ctx.fill(r)
            }

            // 0.5 Boxes (actor groups)
            for box in boxes {
                let boxRect = CGRect(x: box.x, y: box.y, width: box.width, height: box.height)
                let fillColor = _parseCSSColor(box.fill) ?? theme.effectiveSurface().cgColor.copy(alpha: 0.1)!
                ctx.setFillColor(fillColor)
                ctx.fill(boxRect)
                ctx.setStrokeColor(fillColor.copy(alpha: 0.6)!)
                ctx.setLineWidth(1.0)
                ctx.setLineDash(phase: 0, lengths: [6, 4])
                let path = BMBezierPath(roundedRect: boxRect, cornerRadius: 4)
                ctx.addPath(path.bm_cgPath)
                ctx.strokePath()
                ctx.setLineDash(phase: 0, lengths: [])

                if let name = box.name, !name.isEmpty {
                    self._drawTextInFlipped(name, at: CGPoint(x: box.x + 6, y: box.y + 14),
                        context: ctx, contentHeight: ch,
                        color: theme.effectiveMuted(),
                        font: cfg.edgeLabelFont(),
                        alignment: .left)
                }
            }

            // 1. Block regions (loop/alt/opt/par/critical) — skip rect highlights
            for block in blocks where !block.isHighlight {
                let blockRect = CGRect(x: block.x, y: block.y, width: block.width, height: block.height)
                ctx.setStrokeColor(theme.effectiveBorder().cgColor)
                ctx.setLineWidth(cfg.strokeWidthOuterBox)
                ctx.stroke(blockRect)

                let labelText = block.label.isEmpty ? block.type : "\(block.type) [\(block.label)]"
                let tabWidth = cfg.estimateTextWidth(labelText, fontSize: cfg.fontSizeEdgeLabel, fontWeight: cfg.fontWeightGroupHeader) + 16
                let tabHeight = cfg.sequenceTabHeight
                let tabRect = CGRect(x: block.x, y: block.y, width: tabWidth, height: tabHeight)
                ctx.setFillColor(theme.subgraphHeaderColor().cgColor)
                ctx.fill(tabRect)
                ctx.setStrokeColor(theme.effectiveBorder().cgColor)
                ctx.stroke(tabRect)

                self._drawTextInFlipped(labelText, at: CGPoint(x: block.x + 6, y: block.y + tabHeight / 2),
                    context: ctx, contentHeight: ch,
                    color: theme.effectiveTextSecondary(),
                    font: cfg.groupHeaderFont(),
                    alignment: .left)

                for divider in block.dividers {
                    ctx.saveGState()
                    ctx.setStrokeColor(theme.effectiveLine().cgColor)
                    ctx.setLineWidth(0.75)
                    ctx.setLineDash(phase: 0, lengths: [6, 4])
                    ctx.move(to: CGPoint(x: block.x, y: divider.y))
                    ctx.addLine(to: CGPoint(x: block.x + block.width, y: divider.y))
                    ctx.strokePath()
                    ctx.restoreGState()
                    if !divider.label.isEmpty {
                        self._drawTextInFlipped("[\(divider.label)]", at: CGPoint(x: block.x + 8, y: divider.y + 14),
                            context: ctx, contentHeight: ch,
                            color: theme.effectiveMuted(),
                            font: cfg.edgeLabelFont(),
                            alignment: .left)
                    }
                }
            }

            // 2. Lifelines (dashed vertical lines)
            ctx.saveGState()
            ctx.setStrokeColor(theme.effectiveLine().cgColor)
            ctx.setLineWidth(0.75)
            ctx.setLineDash(phase: 0, lengths: [6, 4])
            if lifelines.isEmpty {
                let maxY = messages.map(\.y).max() ?? 300
                for actor in actors {
                    ctx.move(to: CGPoint(x: actor.x, y: actor.y + actor.height))
                    ctx.addLine(to: CGPoint(x: actor.x, y: maxY + 60))
                    ctx.strokePath()
                }
            } else {
                for ll in lifelines {
                    ctx.move(to: CGPoint(x: ll.x, y: ll.topY))
                    ctx.addLine(to: CGPoint(x: ll.x, y: ll.bottomY))
                    ctx.strokePath()
                }
            }
            ctx.restoreGState()

            // 3. Activation bars
            for act in activations {
                let h = max(0, act.bottomY - act.topY)
                let actRect = CGRect(x: act.x, y: act.topY, width: act.width, height: h)
                ctx.setFillColor(theme.effectiveSurface().cgColor)
                ctx.fill(actRect)
                ctx.setStrokeColor(theme.effectiveBorder().cgColor)
                ctx.setLineWidth(cfg.strokeWidthInnerBox)
                ctx.stroke(actRect)
            }

            // 4. Messages (arrows with labels)
            for msg in messages {
                ctx.saveGState()
                ctx.setStrokeColor(theme.effectiveLine().cgColor)
                ctx.setLineWidth(cfg.strokeWidthConnector)
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)

                if msg.lineStyle == "dashed" {
                    ctx.setLineDash(phase: 0, lengths: [6, 4])
                }

                let style = SequenceArrowStyle(type: msg.arrowType)

                // Sequence number
                if msg.sequenceVisible, let num = msg.sequenceNumber {
                    let numX = msg.isSelf ? msg.x1 - 18 : min(msg.x1, msg.x2) - 18
                    self._drawTextInFlipped("\(Int(num))", at: CGPoint(x: numX, y: msg.y - 2),
                        context: ctx, contentHeight: ch,
                        color: theme.effectiveMuted(),
                        font: cfg.edgeLabelFont(),
                        alignment: .right)
                }

                // Central connection circles
                if let cc = msg.centralConnection, (cc == .source || cc == .both) {
                    _drawCentralCircle(at: CGPoint(x: msg.isSelf ? msg.x1 : msg.x1, y: msg.y), in: ctx, theme: theme)
                }
                if let cc = msg.centralConnection, (cc == .dest || cc == .both) {
                    _drawCentralCircle(at: CGPoint(x: msg.isSelf ? msg.x2 : msg.x2, y: msg.y), in: ctx, theme: theme)
                }

                if msg.isSelf {
                    let loopW: CGFloat = 28, loopH: CGFloat = 20
                    let pts = [
                        CGPoint(x: msg.x1, y: msg.y),
                        CGPoint(x: msg.x1 + loopW, y: msg.y),
                        CGPoint(x: msg.x1 + loopW, y: msg.y + loopH),
                        CGPoint(x: msg.x2, y: msg.y + loopH),
                    ]
                    ctx.move(to: pts[0])
                    for p in pts.dropFirst() { ctx.addLine(to: p) }
                    ctx.strokePath()
                    ctx.restoreGState()

                    guard let lastPt = pts.last else { continue }
                    _drawSequenceArrowHead(at: lastPt, from: pts[pts.count - 2], arrowType: msg.arrowType, in: ctx)
                    self._drawTextInFlipped(msg.label, at: CGPoint(x: msg.x1 + loopW + 4, y: msg.y + loopH / 2),
                        context: ctx, contentHeight: ch,
                        color: theme.effectiveMuted(),
                        font: cfg.edgeLabelFont(),
                        alignment: .left)
                } else {
                    ctx.move(to: CGPoint(x: msg.x1, y: msg.y))
                    ctx.addLine(to: CGPoint(x: msg.x2, y: msg.y))
                    ctx.strokePath()
                    ctx.restoreGState()

                    _drawSequenceArrowHead(at: CGPoint(x: msg.x2, y: msg.y), from: CGPoint(x: msg.x1, y: msg.y), arrowType: msg.arrowType, in: ctx)

                    // Bidirectional: arrow at both ends
                    if style.isBidirectional {
                        _drawSequenceArrowHead(at: CGPoint(x: msg.x1, y: msg.y), from: CGPoint(x: msg.x2, y: msg.y), arrowType: msg.arrowType, in: ctx)
                    }

                    self._drawTextInFlipped(msg.label, at: CGPoint(x: (msg.x1 + msg.x2) / 2, y: msg.y - 8),
                        context: ctx, contentHeight: ch,
                        color: theme.effectiveMuted(),
                        font: cfg.edgeLabelFont(),
                        alignment: .center)
                }
            }

            // 5. Notes
            for note in notes {
                let noteRect = CGRect(x: note.x, y: note.y, width: note.width, height: note.height)
                let foldSize: CGFloat = 6

                let notePath = CGMutablePath()
                notePath.move(to: CGPoint(x: noteRect.minX, y: noteRect.minY))
                notePath.addLine(to: CGPoint(x: noteRect.maxX - foldSize, y: noteRect.minY))
                notePath.addLine(to: CGPoint(x: noteRect.maxX, y: noteRect.minY + foldSize))
                notePath.addLine(to: CGPoint(x: noteRect.maxX, y: noteRect.maxY))
                notePath.addLine(to: CGPoint(x: noteRect.minX, y: noteRect.maxY))
                notePath.closeSubpath()

                ctx.setFillColor(theme.subgraphHeaderColor().cgColor)
                ctx.addPath(notePath)
                ctx.fillPath()
                ctx.setStrokeColor(theme.effectiveBorder().cgColor)
                ctx.setLineWidth(cfg.strokeWidthInnerBox)
                ctx.addPath(notePath)
                ctx.strokePath()

                let foldPath = CGMutablePath()
                foldPath.move(to: CGPoint(x: noteRect.maxX - foldSize, y: noteRect.minY))
                foldPath.addLine(to: CGPoint(x: noteRect.maxX - foldSize, y: noteRect.minY + foldSize))
                foldPath.addLine(to: CGPoint(x: noteRect.maxX, y: noteRect.minY + foldSize))
                foldPath.closeSubpath()
                ctx.setFillColor(theme.effectiveBorder().cgColor)
                ctx.addPath(foldPath)
                ctx.fillPath()

                if !note.text.isEmpty {
                    let inset = noteRect.insetBy(dx: 6, dy: 4)
                    self.labelRenderer.drawMultilineText(note.text, in: inset, context: ctx,
                        color: theme.effectiveMuted(), font: cfg.edgeLabelFont(), alignment: .center)
                }
            }

            // 6. Actor boxes (on top)
            for actor in actors {
                _drawActorTyped(actor, in: ctx, contentHeight: ch)
            }

            // 7. Mirror actors at bottom
            for actor in bottomActors {
                _drawActorTyped(actor, in: ctx, contentHeight: ch)
            }
        }
    }

    // MARK: - Arrow Head (CG)

    private func _drawSequenceArrowHead(at point: CGPoint, from prev: CGPoint, arrowType: SequenceArrowType, in context: CGContext) {
        let config = self.config
        let style = SequenceArrowStyle(type: arrowType)
        let arrowColor = theme.effectiveArrow().cgColor
        let lineWidth = config.strokeWidthConnector
        let arrowWidth: CGFloat = config.arrowHeadWidth * lineWidth
        let arrowHeight: CGFloat = config.arrowHeadHeight * lineWidth
        let angle = atan2(point.y - prev.y, point.x - prev.x)

        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        context.rotate(by: angle)
        context.setStrokeColor(arrowColor)
        context.setFillColor(arrowColor)
        context.setLineWidth(lineWidth)

        if style.isCross {
            // X mark
            let cs: CGFloat = arrowHeight * 0.7
            context.move(to: CGPoint(x: -cs, y: -cs))
            context.addLine(to: CGPoint(x: 0, y: cs))
            context.move(to: CGPoint(x: -cs, y: cs))
            context.addLine(to: CGPoint(x: 0, y: -cs))
            context.strokePath()
        } else if style.isOpenArrow {
            // Async open arc
            context.move(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
            context.addQuadCurve(to: CGPoint(x: -arrowWidth * 0.2, y: arrowHeight / 2), control: CGPoint(x: -arrowWidth * 1.5, y: 0))
            context.strokePath()
        } else if !style.hasArrowEnd {
            // No arrowhead — nothing to draw
        } else if style.isHalfArrow {
            _drawHalfArrowHead(at: style, in: context, arrowWidth: arrowWidth, arrowHeight: arrowHeight)
        } else {
            // Filled triangle
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
            path.addLine(to: CGPoint(x: -arrowWidth, y: arrowHeight / 2))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        }

        context.restoreGState()
    }

    private func _drawHalfArrowHead(at style: SequenceArrowStyle, in context: CGContext, arrowWidth: CGFloat, arrowHeight: CGFloat) {
        let isStick = style.halfArrowStyle == .stick
        let isTop = style.halfArrowDirection == .top
        let isReversed = style.isReversed

        if isStick {
            // Stick: thin vertical line + horizontal tick
            let half = arrowHeight / 2
            let top = isTop ? -half : 0
            let bottom = isTop ? 0 : half
            context.move(to: CGPoint(x: 0, y: top))
            context.addLine(to: CGPoint(x: 0, y: bottom))
            // Horizontal tick
            let tickX = isReversed ? arrowWidth * 0.7 : -arrowWidth * 0.7
            let tickY = isReversed ? (isTop ? top : bottom) : (isTop ? top : bottom)
            let tickDelta: CGFloat = isReversed ? (isTop ? -2 : 2) : (isTop ? -2 : 2)
            context.move(to: CGPoint(x: 0, y: tickY))
            context.addLine(to: CGPoint(x: tickX, y: tickY + tickDelta))
            context.strokePath()
        } else {
            // Half triangle
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            if isReversed {
                if isTop {
                    // Reverse top: triangle points right-up (mirrored)
                    path.addLine(to: CGPoint(x: arrowWidth, y: -arrowHeight / 2))
                    path.addLine(to: CGPoint(x: arrowWidth, y: 0))
                } else {
                    // Reverse bottom: triangle points right-down (mirrored)
                    path.addLine(to: CGPoint(x: arrowWidth, y: 0))
                    path.addLine(to: CGPoint(x: arrowWidth, y: arrowHeight / 2))
                }
            } else {
                if isTop {
                    path.addLine(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
                    path.addLine(to: CGPoint(x: -arrowWidth, y: 0))
                } else {
                    path.addLine(to: CGPoint(x: -arrowWidth, y: 0))
                    path.addLine(to: CGPoint(x: -arrowWidth, y: arrowHeight / 2))
                }
            }
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
        }
    }

    private func _drawCentralCircle(at point: CGPoint, in ctx: CGContext, theme: DiagramTheme) {
        let r: CGFloat = 5
        let rect = CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)
        ctx.saveGState()
        ctx.setFillColor(theme.background.cgColor)
        ctx.fillEllipse(in: rect)
        ctx.setStrokeColor(theme.effectiveLine().cgColor)
        ctx.setLineWidth(1.0)
        ctx.strokeEllipse(in: rect)
        ctx.restoreGState()
    }

    // MARK: - Actor Typed Drawing (CG)

    private func _drawActorTyped(_ actor: PositionedSequenceActor, in context: CGContext, contentHeight: Double) {
        let pType = actor.participantType

        switch pType {
        case .actor:
            _drawActorStickFigure(actor, in: context, contentHeight: contentHeight)
        case .participant:
            _drawActorRectangle(actor, in: context, contentHeight: contentHeight)
        case .boundary:
            _drawActorBoundary(actor, in: context, contentHeight: contentHeight)
        case .control:
            _drawActorControl(actor, in: context, contentHeight: contentHeight)
        case .entity:
            _drawActorEntity(actor, in: context, contentHeight: contentHeight)
        case .database:
            _drawActorDatabase(actor, in: context, contentHeight: contentHeight)
        case .collections:
            _drawActorCollections(actor, in: context, contentHeight: contentHeight)
        case .queue:
            _drawActorQueue(actor, in: context, contentHeight: contentHeight)
        }
    }

    private func _drawActorRectangle(_ actor: PositionedSequenceActor, in context: CGContext, contentHeight: Double) {
        let box = CGRect(x: actor.x - actor.width / 2, y: actor.y, width: actor.width, height: actor.height)
        let path = BMBezierPath(roundedRect: box, cornerRadius: 4)
        context.setFillColor(theme.effectiveSurface().cgColor)
        context.addPath(path.bm_cgPath)
        context.fillPath()
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(1.0)
        context.addPath(path.bm_cgPath)
        context.strokePath()
        _drawTextInFlipped(actor.label, at: CGPoint(x: box.midX, y: box.midY),
            context: context, contentHeight: contentHeight,
            color: theme.foreground, font: config.nodeLabelFont(), alignment: .center)
    }

    private func _drawActorStickFigure(_ actor: PositionedSequenceActor, in context: CGContext, contentHeight: Double) {
        let cx = actor.x
        let boxTop = actor.y
        let figH = actor.height - 16
        let scale = figH / 24.0
        let originX = cx - 12 * scale
        let originY = boxTop

        context.saveGState()
        context.setStrokeColor(theme.effectiveLine().cgColor)
        context.setLineWidth(1.5)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let outerR = 11.0 * scale
        context.strokeEllipse(in: CGRect(x: originX + 12 * scale - outerR, y: originY + 12 * scale - outerR, width: outerR * 2, height: outerR * 2))

        let headR = 3.0 * scale
        context.strokeEllipse(in: CGRect(x: originX + 12 * scale - headR, y: originY + 10 * scale - headR, width: headR * 2, height: headR * 2))

        let path = CGMutablePath()
        path.move(to: CGPoint(x: originX + 5.6 * scale, y: originY + 18.4 * scale))
        path.addQuadCurve(to: CGPoint(x: originX + 18.4 * scale, y: originY + 18.4 * scale),
            control: CGPoint(x: originX + 12 * scale, y: originY + 16 * scale))
        context.addPath(path)
        context.strokePath()
        context.restoreGState()

        _drawTextInFlipped(actor.label, at: CGPoint(x: cx, y: boxTop + figH + 8),
            context: context, contentHeight: contentHeight,
            color: theme.foreground, font: config.nodeLabelFont(), alignment: .center)
    }

    private func _drawActorBoundary(_ actor: PositionedSequenceActor, in context: CGContext, contentHeight: Double) {
        let r = min(actor.width, actor.height) / 2 - 2
        let cy = actor.y + actor.height / 2
        context.saveGState()
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(config.strokeWidthOuterBox)
        context.strokeEllipse(in: CGRect(x: actor.x - r, y: cy - r, width: r * 2, height: r * 2))
        // Vertical line through center
        context.move(to: CGPoint(x: actor.x, y: cy - r))
        context.addLine(to: CGPoint(x: actor.x, y: cy + r))
        context.setLineWidth(config.strokeWidthInnerBox)
        context.strokePath()
        context.restoreGState()
        _drawTextInFlipped(actor.label, at: CGPoint(x: actor.x, y: actor.y + actor.height + 14),
            context: context, contentHeight: contentHeight,
            color: theme.foreground, font: config.nodeLabelFont(), alignment: .center)
    }

    private func _drawActorControl(_ actor: PositionedSequenceActor, in context: CGContext, contentHeight: Double) {
        let r = min(actor.width, actor.height) / 2 - 2
        let cy = actor.y + actor.height / 2
        context.saveGState()
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(config.strokeWidthOuterBox)
        context.strokeEllipse(in: CGRect(x: actor.x - r, y: cy - r, width: r * 2, height: r * 2))
        // Arrow at top
        let arTop = cy - r
        context.setFillColor(theme.effectiveBorder().cgColor)
        let arrPath = CGMutablePath()
        arrPath.move(to: CGPoint(x: actor.x, y: arTop - 6))
        arrPath.addLine(to: CGPoint(x: actor.x - 5, y: arTop))
        arrPath.addLine(to: CGPoint(x: actor.x + 5, y: arTop))
        arrPath.closeSubpath()
        context.addPath(arrPath)
        context.fillPath()
        context.restoreGState()
        _drawTextInFlipped(actor.label, at: CGPoint(x: actor.x, y: actor.y + actor.height + 14),
            context: context, contentHeight: contentHeight,
            color: theme.foreground, font: config.nodeLabelFont(), alignment: .center)
    }

    private func _drawActorEntity(_ actor: PositionedSequenceActor, in context: CGContext, contentHeight: Double) {
        let r = min(actor.width, actor.height) / 2 - 2
        let cy = actor.y + actor.height / 2
        context.saveGState()
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(config.strokeWidthOuterBox)
        context.strokeEllipse(in: CGRect(x: actor.x - r, y: cy - r, width: r * 2, height: r * 2))
        // Horizontal line at bottom
        context.move(to: CGPoint(x: actor.x - r, y: cy + r * 0.6))
        context.addLine(to: CGPoint(x: actor.x + r, y: cy + r * 0.6))
        context.setLineWidth(config.strokeWidthInnerBox)
        context.strokePath()
        context.restoreGState()
        _drawTextInFlipped(actor.label, at: CGPoint(x: actor.x, y: actor.y + actor.height + 14),
            context: context, contentHeight: contentHeight,
            color: theme.foreground, font: config.nodeLabelFont(), alignment: .center)
    }

    private func _drawActorDatabase(_ actor: PositionedSequenceActor, in context: CGContext, contentHeight: Double) {
        let boxX = actor.x - actor.width / 2
        let w = actor.width
        let h = actor.height
        let ellH: CGFloat = 6
        context.saveGState()
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(config.strokeWidthOuterBox)
        context.setFillColor(theme.effectiveSurface().cgColor)

        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: boxX, y: actor.y + ellH))
        bodyPath.addLine(to: CGPoint(x: boxX, y: actor.y + h - ellH))
        bodyPath.addArc(center: CGPoint(x: actor.x, y: actor.y + h - ellH), radius: w / 2, startAngle: .pi, endAngle: 0, clockwise: false)
        bodyPath.addLine(to: CGPoint(x: boxX + w, y: actor.y + ellH))
        bodyPath.addArc(center: CGPoint(x: actor.x, y: actor.y + ellH), radius: w / 2, startAngle: 0, endAngle: .pi, clockwise: false)
        bodyPath.closeSubpath()
        context.addPath(bodyPath)
        context.fillPath()
        context.addPath(bodyPath)
        context.strokePath()

        // Top ellipse
        context.strokeEllipse(in: CGRect(x: boxX, y: actor.y, width: w, height: ellH * 2))
        context.restoreGState()
        _drawTextInFlipped(actor.label, at: CGPoint(x: actor.x, y: actor.y + h + 14),
            context: context, contentHeight: contentHeight,
            color: theme.foreground, font: config.nodeLabelFont(), alignment: .center)
    }

    private func _drawActorCollections(_ actor: PositionedSequenceActor, in context: CGContext, contentHeight: Double) {
        let boxX = actor.x - actor.width / 2
        let offsetX: CGFloat = 3
        let offsetY: CGFloat = -3
        context.saveGState()
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(config.strokeWidthInnerBox)
        context.stroke(CGRect(x: boxX + offsetX, y: actor.y + offsetY, width: actor.width, height: actor.height))
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(config.strokeWidthOuterBox)
        context.setFillColor(theme.effectiveSurface().cgColor)
        let mainRect = CGRect(x: boxX, y: actor.y, width: actor.width, height: actor.height)
        context.fill(mainRect)
        context.stroke(mainRect)
        context.restoreGState()
        _drawTextInFlipped(actor.label, at: CGPoint(x: actor.x + offsetX / 2, y: actor.y + actor.height + 14),
            context: context, contentHeight: contentHeight,
            color: theme.foreground, font: config.nodeLabelFont(), alignment: .center)
    }

    private func _drawActorQueue(_ actor: PositionedSequenceActor, in context: CGContext, contentHeight: Double) {
        let boxX = actor.x - actor.width / 2
        let w = actor.width
        let h = actor.height
        context.saveGState()
        context.setStrokeColor(theme.effectiveBorder().cgColor)
        context.setLineWidth(config.strokeWidthOuterBox)
        context.setFillColor(theme.effectiveSurface().cgColor)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: boxX, y: actor.y))
        path.addLine(to: CGPoint(x: boxX, y: actor.y + h))
        path.addLine(to: CGPoint(x: boxX + w, y: actor.y + h))
        path.addArc(center: CGPoint(x: actor.x, y: actor.y + h), radius: w / 2, startAngle: .pi, endAngle: 0, clockwise: false)
        path.addLine(to: CGPoint(x: boxX + w, y: actor.y))
        path.addArc(center: CGPoint(x: actor.x, y: actor.y), radius: w / 2, startAngle: 0, endAngle: .pi, clockwise: false)
        path.closeSubpath()
        context.addPath(path)
        context.fillPath()
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
        _drawTextInFlipped(actor.label, at: CGPoint(x: actor.x, y: actor.y + h + 14),
            context: context, contentHeight: contentHeight,
            color: theme.foreground, font: config.nodeLabelFont(), alignment: .center)
    }

    // MARK: - Color helper

    private func _parseCSSColor(_ str: String) -> CGColor? {
        let s = str.lowercased()
        if s == "transparent" { return CGColor(red: 0, green: 0, blue: 0, alpha: 0) }
        // rgb(r,g,b) / rgba(r,g,b,a)
        if let m = try? NSRegularExpression(pattern: #"rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+))?\s*\)"#, options: [])
            .firstMatch(in: s, options: [], range: NSRange(s.startIndex..., in: s)),
           let r1 = Range(m.range(at: 1), in: s), let r2 = Range(m.range(at: 2), in: s), let r3 = Range(m.range(at: 3), in: s) {
            let r = CGFloat(Int(s[r1]) ?? 0) / 255
            let g = CGFloat(Int(s[r2]) ?? 0) / 255
            let b = CGFloat(Int(s[r3]) ?? 0) / 255
            let a: CGFloat
            if let r4 = Range(m.range(at: 4), in: s), let val = Double(s[r4]) {
                a = CGFloat(val)
            } else {
                a = 1.0
            }
            return CGColor(red: r, green: g, blue: b, alpha: a)
        }
        return nil
    }
}
#endif
