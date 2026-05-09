// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import CoreGraphics

extension DiagramRenderer {
    func _drawWardley(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case .wardleyBeta(let diagram) = positioned.content else { return }
        _withFittedContext(context, bounds: bounds, contentWidth: diagram.width, contentHeight: diagram.height) { ctx in
            let theme = diagram.theme ?? .default
            let config = diagram.config
            let nodeRadius = config.nodeRadius

            if !self.theme.transparent {
                ctx.setFillColor(BMColor(hex: theme.backgroundColor).cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: diagram.width, height: diagram.height))
            }

            // Axes
            let axisColor = BMColor(hex: theme.axisColor).cgColor
            ctx.setStrokeColor(axisColor)
            ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: diagram.padding, y: diagram.height - diagram.padding))
            ctx.addLine(to: CGPoint(x: diagram.width - diagram.padding, y: diagram.height - diagram.padding))
            ctx.move(to: CGPoint(x: diagram.padding, y: diagram.height - diagram.padding))
            ctx.addLine(to: CGPoint(x: diagram.padding, y: diagram.padding))
            ctx.strokePath()

            _drawTextInFlipped(
                diagram.axes.xLabel ?? "Evolution",
                at: CGPoint(x: diagram.width / 2, y: diagram.height - diagram.padding / 4),
                context: ctx,
                contentHeight: diagram.height,
                color: BMColor(hex: theme.axisTextColor),
                font: _monoFont(size: config.axisFontSize),
                alignment: .center
            )
            _drawWardleyRotatedText(
                diagram.axes.yLabel ?? "Visibility",
                at: CGPoint(x: diagram.padding / 4, y: diagram.height / 2),
                angle: -.pi / 2,
                context: ctx,
                color: BMColor(hex: theme.axisTextColor),
                font: _monoFont(size: config.axisFontSize)
            )

            // Stage dividing lines
            for stage in diagram.stages {
                ctx.setStrokeColor(axisColor)
                ctx.setLineWidth(1)
                ctx.setLineDash(phase: 0, lengths: [5, 5])
                ctx.move(to: CGPoint(x: stage.startX, y: diagram.padding))
                ctx.addLine(to: CGPoint(x: stage.startX, y: diagram.height - diagram.padding))
                ctx.strokePath()
                ctx.setLineDash(phase: 0, lengths: [])
                _drawTextInFlipped(
                    stage.name,
                    at: CGPoint(x: stage.centerX, y: stage.labelY),
                    context: ctx,
                    contentHeight: diagram.height,
                    color: BMColor(hex: theme.axisTextColor),
                    font: _monoFont(size: max(8, config.axisFontSize - 2)),
                    alignment: .center
                )
            }

            // Grid lines
            if diagram.showGrid {
                let gridColor = BMColor(hex: theme.gridColor).cgColor
                ctx.setStrokeColor(gridColor)
                ctx.setLineWidth(1)
                ctx.setLineDash(phase: 0, lengths: [2, 6])
                for grid in diagram.gridLines {
                    ctx.move(to: CGPoint(x: grid.x1, y: grid.y1))
                    ctx.addLine(to: CGPoint(x: grid.x2, y: grid.y2))
                }
                ctx.strokePath()
                ctx.setLineDash(phase: 0, lengths: [])
            }

            // Pipeline boxes
            let componentStrokeCG = BMColor(hex: theme.componentStroke).cgColor
            for box in diagram.pipelineBoxes {
                ctx.setStrokeColor(componentStrokeCG)
                ctx.setLineWidth(1.5)
                ctx.addPath(_roundedRect(x: box.x, y: box.y, width: box.width, height: box.height, radius: 4))
                ctx.strokePath()

                // Pipeline child links
                ctx.setStrokeColor(componentStrokeCG)
                ctx.setLineWidth(1)
                ctx.setLineDash(phase: 0, lengths: [4, 4])
                for cl in box.childLinks {
                    ctx.move(to: CGPoint(x: cl.x1, y: cl.y1))
                    ctx.addLine(to: CGPoint(x: cl.x2, y: cl.y2))
                }
                ctx.strokePath()
                ctx.setLineDash(phase: 0, lengths: [])
            }

            // Links
            let linkColor = BMColor(hex: theme.linkStroke).cgColor
            for link in diagram.validLinks {
                ctx.setStrokeColor(linkColor)
                ctx.setLineWidth(1)
                if link.dashed {
                    ctx.setLineDash(phase: 0, lengths: [6, 6])
                }
                ctx.move(to: CGPoint(x: link.sourceX, y: link.sourceY))
                ctx.addLine(to: CGPoint(x: link.targetX, y: link.targetY))
                ctx.strokePath()
                ctx.setLineDash(phase: 0, lengths: [])
                if link.flow == .forward || link.flow == .bidirectional {
                    _drawWardleyArrowhead(
                        ctx,
                        tip: CGPoint(x: link.targetX, y: link.targetY),
                        tail: CGPoint(x: link.sourceX, y: link.sourceY),
                        size: 7,
                        color: linkColor
                    )
                }
                if link.flow == .backward || link.flow == .bidirectional {
                    _drawWardleyArrowhead(
                        ctx,
                        tip: CGPoint(x: link.sourceX, y: link.sourceY),
                        tail: CGPoint(x: link.targetX, y: link.targetY),
                        size: 7,
                        color: linkColor
                    )
                }
                if let label = link.label, let x = link.labelX, let y = link.labelY {
                    _drawWardleyRotatedText(
                        label,
                        at: CGPoint(x: x, y: y),
                        angle: CGFloat((link.labelAngle ?? 0) * .pi / 180),
                        context: ctx,
                        color: BMColor(hex: theme.componentLabelColor),
                        font: _monoFont(size: max(8, config.labelFontSize - 2))
                    )
                }
            }

            // Trends
            let evolutionCG = BMColor(hex: theme.evolutionStroke).cgColor
            for trend in diagram.trends {
                ctx.setStrokeColor(evolutionCG)
                ctx.setLineWidth(1)
                ctx.setLineDash(phase: 0, lengths: [4, 4])
                ctx.move(to: CGPoint(x: trend.originX, y: trend.originY))
                ctx.addLine(to: CGPoint(x: trend.targetX, y: trend.targetY))
                ctx.strokePath()
                ctx.setLineDash(phase: 0, lengths: [])
                _drawWardleyArrowhead(
                    ctx,
                    tip: CGPoint(x: trend.targetX, y: trend.targetY),
                    tail: CGPoint(x: trend.originX, y: trend.originY),
                    size: 8,
                    color: evolutionCG
                )
            }

            // Nodes
            let componentFillCG = BMColor(hex: theme.componentFill).cgColor
            let labelColorCG = BMColor(hex: theme.componentLabelColor)

            for node in diagram.nodes {
                // Source strategy overlays
                switch node.sourceStrategy {
                case .outsource:
                    ctx.setFillColor(CGColor(gray: 0.4, alpha: 1))
                    _fillCircle(ctx, x: node.x, y: node.y, r: nodeRadius * 2)
                case .buy:
                    ctx.setFillColor(CGColor(gray: 0.8, alpha: 1))
                    _fillCircle(ctx, x: node.x, y: node.y, r: nodeRadius * 2)
                case .build:
                    ctx.setFillColor(CGColor(gray: 0.933, alpha: 1))
                    _fillCircle(ctx, x: node.x, y: node.y, r: nodeRadius * 2)
                    ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
                    _strokeCircle(ctx, x: node.x, y: node.y, r: nodeRadius * 2)
                case .market:
                    ctx.setFillColor(componentFillCG)
                    _fillCircle(ctx, x: node.x, y: node.y, r: nodeRadius * 2)
                    ctx.setStrokeColor(componentStrokeCG)
                    _strokeCircle(ctx, x: node.x, y: node.y, r: nodeRadius * 2)
                    _drawWardleyMarketGlyph(ctx, x: node.x, y: node.y, radius: nodeRadius * 2, stroke: componentStrokeCG, fill: componentFillCG)
                case .none:
                    break
                }

                // Main node shape
                if node.isPipelineParent {
                    let sqSize = nodeRadius * 1.6
                    ctx.setFillColor(componentFillCG)
                    ctx.setStrokeColor(componentStrokeCG)
                    let rect = CGRect(x: node.x - sqSize / 2, y: node.y - sqSize / 2, width: sqSize, height: sqSize)
                    ctx.fill(rect)
                    ctx.stroke(rect)
                } else if node.className != .anchor {
                    ctx.setFillColor(componentFillCG)
                    ctx.setStrokeColor(componentStrokeCG)
                    _fillAndStrokeCircle(ctx, x: node.x, y: node.y, r: nodeRadius)
                }

                // Inertia line
                if node.inertia {
                    var offset = nodeRadius + 6
                    if node.sourceStrategy != nil { offset = nodeRadius * 2 + 10 }
                    ctx.setStrokeColor(componentStrokeCG)
                    ctx.setLineWidth(6)
                    ctx.setLineCap(.round)
                    ctx.move(to: CGPoint(x: node.x + offset, y: node.y - 8))
                    ctx.addLine(to: CGPoint(x: node.x + offset, y: node.y + 8))
                    ctx.strokePath()
                    ctx.setLineWidth(1)
                    ctx.setLineCap(.butt)
                }

                // Node label
                let labelOffsetX = node.labelOffsetX ?? config.nodeLabelOffset
                let labelOffsetY = node.labelOffsetY ?? 0
                if node.className == .anchor {
                    _drawTextInFlipped(
                        node.label,
                        at: CGPoint(x: node.x, y: node.y - nodeRadius - 3),
                        context: ctx,
                        contentHeight: diagram.height,
                        color: BMColor(hex: theme.axisTextColor),
                        font: _monoFont(size: config.labelFontSize),
                        alignment: .center
                    )
                } else {
                    _drawTextInFlipped(
                        node.label,
                        at: CGPoint(x: node.x + labelOffsetX, y: node.y + labelOffsetY),
                        context: ctx,
                        contentHeight: diagram.height,
                        color: labelColorCG,
                        font: _monoFont(size: config.labelFontSize),
                        alignment: .left
                    )
                }
            }

            // Annotations
            let annotationStrokeCG = BMColor(hex: theme.annotationStroke).cgColor
            let annotationFillCG = BMColor(hex: theme.annotationFill).cgColor
            for point in diagram.annotationPoints {
                ctx.setStrokeColor(annotationStrokeCG)
                ctx.setLineWidth(1)
                ctx.setLineDash(phase: 0, lengths: [4, 4])
                for line in point.connectingLines {
                    ctx.move(to: CGPoint(x: line.x1, y: line.y1))
                    ctx.addLine(to: CGPoint(x: line.x2, y: line.y2))
                }
                ctx.strokePath()
                ctx.setLineDash(phase: 0, lengths: [])

                ctx.setFillColor(annotationFillCG)
                ctx.setStrokeColor(annotationStrokeCG)
                _fillAndStrokeCircle(ctx, x: point.x, y: point.y, r: 10)
                _drawTextInFlipped(
                    "\(point.number)",
                    at: CGPoint(x: point.x, y: point.y),
                    context: ctx,
                    contentHeight: diagram.height,
                    color: BMColor(hex: theme.annotationTextColor),
                    font: _monoFont(size: config.labelFontSize),
                    alignment: .center
                )
            }

            // Annotation box
            if let box = diagram.annotationBox {
                ctx.setFillColor(annotationFillCG)
                ctx.setStrokeColor(annotationStrokeCG)
                ctx.addPath(_roundedRect(x: box.x, y: box.y, width: box.width, height: box.height, radius: 4))
                ctx.fillPath()
                ctx.addPath(_roundedRect(x: box.x, y: box.y, width: box.width, height: box.height, radius: 4))
                ctx.strokePath()

                let annotTextColor = BMColor(hex: theme.annotationTextColor)
                for entry in box.entries {
                    _drawTextInFlipped(
                        entry.text,
                        at: CGPoint(x: entry.x, y: entry.y),
                        context: ctx,
                        contentHeight: diagram.height,
                        color: annotTextColor,
                        font: _monoFont(size: config.labelFontSize - 2),
                        alignment: .left
                    )
                }
            }

            // Notes
            let axisTextColor = BMColor(hex: theme.axisTextColor)
            for note in diagram.notes {
                _drawTextInFlipped(
                    note.text,
                    at: CGPoint(x: note.x, y: note.y),
                    context: ctx,
                    contentHeight: diagram.height,
                    color: axisTextColor,
                    font: _monoFont(size: config.labelFontSize),
                    alignment: .left
                )
            }

            // Accelerators and deaccelerators
            for acc in diagram.accelerators {
                _drawWardleyForceArrow(
                    ctx,
                    center: CGPoint(x: acc.x, y: acc.y),
                    pointsRight: true,
                    fill: componentFillCG,
                    stroke: componentStrokeCG
                )
                _drawTextInFlipped(
                    acc.name,
                    at: CGPoint(x: acc.x, y: acc.y + 42),
                    context: ctx,
                    contentHeight: diagram.height,
                    color: labelColorCG,
                    font: _monoFont(size: config.labelFontSize),
                    alignment: .center
                )
            }
            for dec in diagram.deaccelerators {
                _drawWardleyForceArrow(
                    ctx,
                    center: CGPoint(x: dec.x, y: dec.y),
                    pointsRight: false,
                    fill: componentFillCG,
                    stroke: componentStrokeCG
                )
                _drawTextInFlipped(
                    dec.name,
                    at: CGPoint(x: dec.x, y: dec.y + 42),
                    context: ctx,
                    contentHeight: diagram.height,
                    color: labelColorCG,
                    font: _monoFont(size: config.labelFontSize),
                    alignment: .center
                )
            }

            // Title
            if let title = diagram.diagramTitle {
                _drawTextInFlipped(
                    title,
                    at: CGPoint(x: diagram.width / 2, y: config.padding / 2),
                    context: ctx,
                    contentHeight: diagram.height,
                    color: axisTextColor,
                    font: _monoFont(size: config.axisFontSize * 1.05),
                    alignment: .center
                )
            }
        }
    }

    // MARK: - CG Helpers

    private func _fillCircle(_ ctx: CGContext, x: Double, y: Double, r: Double) {
        ctx.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        ctx.fillPath()
    }

    private func _strokeCircle(_ ctx: CGContext, x: Double, y: Double, r: Double) {
        ctx.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        ctx.strokePath()
    }

    private func _fillAndStrokeCircle(_ ctx: CGContext, x: Double, y: Double, r: Double) {
        ctx.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        ctx.fillPath()
        ctx.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        ctx.strokePath()
    }

    private func _roundedRect(x: Double, y: Double, width: Double, height: Double, radius: Double) -> CGPath {
        let rect = CGRect(x: x, y: y, width: width, height: height)
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        return path
    }

    private func _drawWardleyRotatedText(
        _ text: String,
        at point: CGPoint,
        angle: CGFloat,
        context: CGContext,
        color: BMColor,
        font: BMFont
    ) {
        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        context.rotate(by: angle)
        _drawTextInFlipped(text, at: .zero, context: context, contentHeight: 0, color: color, font: font, alignment: .center)
        context.restoreGState()
    }

    private func _drawWardleyArrowhead(
        _ ctx: CGContext,
        tip: CGPoint,
        tail: CGPoint,
        size: Double,
        color: CGColor
    ) {
        let dx = tip.x - tail.x
        let dy = tip.y - tail.y
        let angle = atan2(dy, dx)
        let wing = CGFloat(size)
        let back = CGPoint(x: tip.x - cos(angle) * wing, y: tip.y - sin(angle) * wing)
        let normal = angle + .pi / 2
        let half = wing * 0.55
        let p1 = CGPoint(x: back.x + cos(normal) * half, y: back.y + sin(normal) * half)
        let p2 = CGPoint(x: back.x - cos(normal) * half, y: back.y - sin(normal) * half)

        ctx.setFillColor(color)
        ctx.beginPath()
        ctx.move(to: tip)
        ctx.addLine(to: p1)
        ctx.addLine(to: p2)
        ctx.closePath()
        ctx.fillPath()
    }

    private func _drawWardleyMarketGlyph(
        _ ctx: CGContext,
        x: Double,
        y: Double,
        radius: Double,
        stroke: CGColor,
        fill: CGColor
    ) {
        let top = CGPoint(x: x, y: y - radius)
        let left = CGPoint(x: x - radius * cos(.pi / 6), y: y + radius * sin(.pi / 6))
        let right = CGPoint(x: x + radius * cos(.pi / 6), y: y + radius * sin(.pi / 6))
        ctx.setStrokeColor(stroke)
        ctx.setLineWidth(1)
        ctx.move(to: top)
        ctx.addLine(to: left)
        ctx.addLine(to: right)
        ctx.addLine(to: top)
        ctx.strokePath()

        ctx.setFillColor(fill)
        ctx.setStrokeColor(stroke)
        for point in [top, left, right] {
            _fillAndStrokeCircle(ctx, x: point.x, y: point.y, r: 2)
        }
    }

    private func _drawWardleyForceArrow(
        _ ctx: CGContext,
        center: CGPoint,
        pointsRight: Bool,
        fill: CGColor,
        stroke: CGColor
    ) {
        let width: CGFloat = 60
        let height: CGFloat = 30
        let headWidth: CGFloat = 20
        let x = center.x - width / 2
        let y = center.y - height / 2

        ctx.beginPath()
        if pointsRight {
            ctx.move(to: CGPoint(x: x, y: y))
            ctx.addLine(to: CGPoint(x: x + width - headWidth, y: y))
            ctx.addLine(to: CGPoint(x: x + width - headWidth, y: y - height / 2))
            ctx.addLine(to: CGPoint(x: x + width, y: center.y))
            ctx.addLine(to: CGPoint(x: x + width - headWidth, y: y + height + height / 2))
            ctx.addLine(to: CGPoint(x: x + width - headWidth, y: y + height))
            ctx.addLine(to: CGPoint(x: x, y: y + height))
        } else {
            ctx.move(to: CGPoint(x: x + width, y: y))
            ctx.addLine(to: CGPoint(x: x + headWidth, y: y))
            ctx.addLine(to: CGPoint(x: x + headWidth, y: y - height / 2))
            ctx.addLine(to: CGPoint(x: x, y: center.y))
            ctx.addLine(to: CGPoint(x: x + headWidth, y: y + height + height / 2))
            ctx.addLine(to: CGPoint(x: x + headWidth, y: y + height))
            ctx.addLine(to: CGPoint(x: x + width, y: y + height))
        }
        ctx.closePath()
        ctx.setFillColor(fill)
        ctx.fillPath()

        ctx.beginPath()
        if pointsRight {
            ctx.move(to: CGPoint(x: x, y: y))
            ctx.addLine(to: CGPoint(x: x + width - headWidth, y: y))
            ctx.addLine(to: CGPoint(x: x + width - headWidth, y: y - height / 2))
            ctx.addLine(to: CGPoint(x: x + width, y: center.y))
            ctx.addLine(to: CGPoint(x: x + width - headWidth, y: y + height + height / 2))
            ctx.addLine(to: CGPoint(x: x + width - headWidth, y: y + height))
            ctx.addLine(to: CGPoint(x: x, y: y + height))
        } else {
            ctx.move(to: CGPoint(x: x + width, y: y))
            ctx.addLine(to: CGPoint(x: x + headWidth, y: y))
            ctx.addLine(to: CGPoint(x: x + headWidth, y: y - height / 2))
            ctx.addLine(to: CGPoint(x: x, y: center.y))
            ctx.addLine(to: CGPoint(x: x + headWidth, y: y + height + height / 2))
            ctx.addLine(to: CGPoint(x: x + headWidth, y: y + height))
            ctx.addLine(to: CGPoint(x: x + width, y: y + height))
        }
        ctx.closePath()
        ctx.setStrokeColor(stroke)
        ctx.setLineWidth(1)
        ctx.strokePath()
    }
}
#endif
