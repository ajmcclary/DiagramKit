import Foundation
import CoreGraphics

extension DiagramRenderer {

    func _drawTimeline(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard let timeline = positioned.timelineData, !timeline.tasks.isEmpty else { return }

        _withFittedContext(context, bounds: bounds,
                           contentWidth: max(1, timeline.width),
                           contentHeight: max(1, timeline.height)) { ctx in
            let ch = max(1, timeline.height)
            let theme = timeline.theme
            let fontSize = CGFloat(timeline.config.taskFontSize)
            let font = BMFont.systemFont(ofSize: fontSize, weight: .regular)
            let titleFont = BMFont.systemFont(ofSize: 18, weight: .bold)
            let isNeo = timeline.look == "neo"
            let themeName = timeline.themeName ?? ""
            let isRedux = themeName.contains("redux")
            let cornerRadius: CGFloat = isRedux ? 0 : 3

            // 1. Section nodes
            for section in timeline.sections {
                let sectionRect = CGRect(x: section.x, y: section.y, width: section.width, height: section.height)
                let path = BMBezierPath(roundedRect: sectionRect, cornerRadius: cornerRadius)

                let colorIdx = section.colorIndex % max(1, theme.cScale.count)
                let fillHex = isNeo ? theme.mainBkg : theme.cScale[colorIdx]
                if let fillColor = MermaidColorParser.cgHex(fillHex) {
                    ctx.setFillColor(fillColor)
                } else {
                    ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                }

                if isRedux && isNeo {
                    ctx.setShadow(offset: CGSize(width: 4, height: 4), blur: 0, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.06))
                }
                ctx.addPath(path.bm_cgPath)
                ctx.fillPath()
                ctx.setShadow(offset: .zero, blur: 0, color: nil)

                let textColor = MermaidColorParser.hexColor(isNeo ? theme.nodeBorder : theme.cScaleLabel[colorIdx]) ?? self.theme.foreground
                self._drawTextInFlipped(
                    section.text,
                    at: CGPoint(x: section.x + section.width / 2, y: section.y + section.height / 2),
                    context: ctx, contentHeight: ch,
                    color: textColor,
                    font: font,
                    alignment: .center
                )
            }

            // 2. Task nodes
            for task in timeline.tasks {
                let taskRect = CGRect(x: task.x, y: task.y, width: task.width, height: task.height)
                let path = BMBezierPath(roundedRect: taskRect, cornerRadius: cornerRadius)

                let colorIdx = task.colorIndex % max(1, theme.cScale.count)
                let fillHex = isNeo ? theme.mainBkg : theme.cScale[colorIdx]
                if let fillColor = MermaidColorParser.cgHex(fillHex) {
                    ctx.setFillColor(fillColor)
                } else {
                    ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                }

                if isRedux && isNeo {
                    ctx.setShadow(offset: CGSize(width: 4, height: 4), blur: 0, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.06))
                }
                ctx.addPath(path.bm_cgPath)
                ctx.fillPath()
                ctx.setShadow(offset: .zero, blur: 0, color: nil)

                // Bottom accent line (non-redux only)
                if !isRedux {
                    if let lineColor = MermaidColorParser.cgHex(theme.cScaleInv[colorIdx]) {
                        ctx.setStrokeColor(lineColor)
                        ctx.setLineWidth(3)
                        ctx.move(to: CGPoint(x: task.x, y: task.y + task.height))
                        ctx.addLine(to: CGPoint(x: task.x + task.width, y: task.y + task.height))
                        ctx.strokePath()
                    }
                }

                let textColor = MermaidColorParser.hexColor(isNeo ? theme.nodeBorder : theme.cScaleLabel[colorIdx]) ?? self.theme.foreground
                self._drawTextInFlipped(
                    task.text,
                    at: CGPoint(x: task.x + task.width / 2, y: task.y + task.height / 2),
                    context: ctx, contentHeight: ch,
                    color: textColor,
                    font: font,
                    alignment: .center
                )
            }

            // 3. Event nodes (with brightness via lighter fill)
            for event in timeline.events {
                let eventRect = CGRect(x: event.x, y: event.y, width: event.width, height: event.height)
                let path = BMBezierPath(roundedRect: eventRect, cornerRadius: cornerRadius)

                let colorIdx = event.colorIndex % max(1, theme.cScale.count)
                let fillHex = isNeo ? theme.mainBkg : theme.cScale[colorIdx]
                if let baseColor = MermaidColorParser.cgHex(fillHex) {
                    let lightened = _brightenColor(baseColor, factor: 1.2)
                    ctx.setFillColor(lightened)
                } else {
                    ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                }

                if isRedux && isNeo {
                    ctx.setShadow(offset: CGSize(width: 4, height: 4), blur: 0, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.06))
                }
                ctx.addPath(path.bm_cgPath)
                ctx.fillPath()
                ctx.setShadow(offset: .zero, blur: 0, color: nil)

                self._drawTextInFlipped(
                    event.text,
                    at: CGPoint(x: event.x + event.width / 2, y: event.y + event.height / 2),
                    context: ctx, contentHeight: ch,
                    color: self.theme.foreground,
                    font: font,
                    alignment: .center
                )
            }

            // 4. Connectors (dashed lines with arrowheads)
            ctx.saveGState()
            ctx.setStrokeColor(self.theme.effectiveMuted().cgColor)
            ctx.setFillColor(self.theme.effectiveMuted().cgColor)
            ctx.setLineWidth(2)
            ctx.setLineDash(phase: 0, lengths: [5, 5])
            for connector in timeline.connectors {
                switch connector.kind {
                case .verticalLR(let x1, let y1, let x2, let y2):
                    ctx.move(to: CGPoint(x: x1, y: y1))
                    ctx.addLine(to: CGPoint(x: x2, y: y2 - 4))
                    ctx.strokePath()
                    ctx.move(to: CGPoint(x: x2 - 3, y: y2 - 4))
                    ctx.addLine(to: CGPoint(x: x2, y: y2))
                    ctx.addLine(to: CGPoint(x: x2 + 3, y: y2 - 4))
                    ctx.closePath()
                    ctx.fillPath()
                case .horizontalTD(let x1, let y1, let x2, let y2):
                    ctx.move(to: CGPoint(x: x1 + 4, y: y1))
                    ctx.addLine(to: CGPoint(x: x2, y: y2))
                    ctx.strokePath()
                    ctx.move(to: CGPoint(x: x2 - 4, y: y2 - 3))
                    ctx.addLine(to: CGPoint(x: x2, y: y2))
                    ctx.addLine(to: CGPoint(x: x2 - 4, y: y2 + 3))
                    ctx.closePath()
                    ctx.fillPath()
                }
            }
            ctx.restoreGState()

            // 5. Activity line with arrowhead
            ctx.saveGState()
            ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
            ctx.setLineWidth(4)
            let line = timeline.activityLine
            ctx.move(to: CGPoint(x: line.x1, y: line.y1))
            ctx.addLine(to: CGPoint(x: line.x2, y: line.y2))
            ctx.strokePath()

            ctx.setFillColor(self.theme.effectiveLine().cgColor)
            if timeline.direction == .LR {
                ctx.move(to: CGPoint(x: line.x2, y: line.y2))
                ctx.addLine(to: CGPoint(x: line.x2 + 6, y: line.y2 - 2))
                ctx.addLine(to: CGPoint(x: line.x2 + 6, y: line.y2 + 2))
            } else {
                ctx.move(to: CGPoint(x: line.x2, y: line.y2))
                ctx.addLine(to: CGPoint(x: line.x2 - 2, y: line.y2 + 6))
                ctx.addLine(to: CGPoint(x: line.x2 + 2, y: line.y2 + 6))
            }
            ctx.closePath()
            ctx.fillPath()
            ctx.restoreGState()

            // 6. Title
            if let title = timeline.title, !title.text.isEmpty {
                self._drawTextInFlipped(
                    title.text,
                    at: CGPoint(x: title.x, y: title.y),
                    context: ctx, contentHeight: ch,
                    color: self.theme.foreground,
                    font: titleFont,
                    alignment: .left
                )
            }
        }
    }

    // MARK: - Color helpers

    // _thexToCGColor / _thexToColor → MermaidColorParser.cgHex(_:)

    private func _brightenColor(_ color: CGColor, factor: CGFloat) -> CGColor {
        guard let components = color.components, components.count >= 3 else { return color }
        let r = min(components[0] * factor, 1.0)
        let g = min(components[1] * factor, 1.0)
        let b = min(components[2] * factor, 1.0)
        let a = components.count >= 4 ? components[3] : 1.0
        return CGColor(red: r, green: g, blue: b, alpha: a)
    }
}
