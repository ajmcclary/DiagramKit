import Foundation
import CoreGraphics

extension DiagramRenderer {

    func _drawJourney(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard let journey = positioned.journeyData, !journey.tasks.isEmpty else { return }

        _withFittedContext(context, bounds: bounds,
                           contentWidth: max(1, journey.width),
                           contentHeight: max(1, journey.height)) { ctx in
            let ch = max(1, journey.height)

            let config = journey.config ?? .default

            // 1. Actor legend
            for actor in journey.actors {
                let circleRect = CGRect(x: actor.circleCenter.x - 7, y: actor.circleCenter.y - 7, width: 14, height: 14)
                if let fillColor = _hexToCGColor(actor.color) {
                    ctx.setFillColor(fillColor)
                } else {
                    ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                }
                ctx.fillEllipse(in: circleRect)

                ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
                ctx.setLineWidth(1)
                ctx.strokeEllipse(in: circleRect)

                let legendFont = BMFont.systemFont(ofSize: CGFloat(config.taskFontSize), weight: .regular)
                for (li, line) in actor.lines.enumerated() {
                    let textY = actor.labelOrigin.y + Double(li) * 16
                    self._drawTextInFlipped(
                        line,
                        at: CGPoint(x: actor.labelOrigin.x, y: textY),
                        context: ctx, contentHeight: ch,
                        color: self.theme.foreground,
                        font: legendFont,
                        alignment: .left
                    )
                }
            }

            // 2. Section rectangles
            for section in journey.sections {
                let sectionRect = CGRect(x: section.x, y: section.y, width: section.width, height: section.height)
                let path = BMBezierPath(roundedRect: sectionRect, cornerRadius: 3)

                if let fillColor = _hexToCGColor(section.fill) {
                    ctx.setFillColor(fillColor)
                } else {
                    ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                }
                ctx.addPath(path.bm_cgPath)
                ctx.fillPath()

                let sectionFont = BMFont.systemFont(ofSize: CGFloat(config.taskFontSize), weight: .regular)
                let splitsBr: Bool
                if config.textPlacement == "old" || config.textPlacement == "fo" {
                    splitsBr = false
                } else {
                    splitsBr = true
                }
                let labelLines = splitsBr
                    ? original_src_multiline_utils.normalizeBrTags(section.name).components(separatedBy: "\n")
                    : [section.name]
                let totalTextHeight = CGFloat(labelLines.count) * CGFloat(config.taskFontSize * 1.3)
                let startY = section.y + (section.height - Double(totalTextHeight)) / 2 + Double(config.taskFontSize * 0.6)

                for (li, line) in labelLines.enumerated() {
                    self._drawTextInFlipped(
                        line,
                        at: CGPoint(x: section.x + section.width / 2, y: startY + Double(li) * config.taskFontSize * 1.3),
                        context: ctx, contentHeight: ch,
                        color: self._hexToColor(section.colour) ?? self.theme.foreground,
                        font: sectionFont,
                        alignment: .center
                    )
                }
            }

            // 3. Tasks
            for task in journey.tasks {
                let taskRect = CGRect(x: task.x, y: task.y, width: task.rectWidth, height: task.rectHeight)
                let path = BMBezierPath(roundedRect: taskRect, cornerRadius: 3)

                if let fillColor = _hexToCGColor(task.fill) {
                    ctx.setFillColor(fillColor)
                } else {
                    ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                }
                ctx.addPath(path.bm_cgPath)
                ctx.fillPath()

                let taskFont = BMFont.systemFont(ofSize: CGFloat(config.taskFontSize), weight: .regular)
                let taskSplitsBr: Bool
                if config.textPlacement == "old" || config.textPlacement == "fo" {
                    taskSplitsBr = false
                } else {
                    taskSplitsBr = true
                }
                let taskLabelLines = taskSplitsBr
                    ? original_src_multiline_utils.normalizeBrTags(task.task).components(separatedBy: "\n")
                    : [task.task]
                let taskTextHeight = CGFloat(taskLabelLines.count) * CGFloat(config.taskFontSize * 1.3)
                let taskStartY = task.y + (task.rectHeight - Double(taskTextHeight)) / 2 + Double(config.taskFontSize * 0.6)

                for (li, line) in taskLabelLines.enumerated() {
                    self._drawTextInFlipped(
                        line,
                        at: CGPoint(x: task.x + task.rectWidth / 2, y: taskStartY + Double(li) * config.taskFontSize * 1.3),
                        context: ctx, contentHeight: ch,
                        color: self._hexToColor(task.colour) ?? self.theme.foreground,
                        font: taskFont,
                        alignment: .center
                    )
                }

                // Actor dots
                let dotCount = task.people.count
                if dotCount > 0 {
                    let spacing = min(10.0, task.rectWidth / Double(dotCount + 1))
                    let startX = task.x + spacing
                    for (di, person) in task.people.enumerated() {
                        if let actorIdx = journey.actors.firstIndex(where: { $0.name == person }) {
                            let dotX = startX + Double(di) * spacing
                            let dotY = task.y
                            let dotRect = CGRect(x: dotX - 7, y: dotY - 7, width: 14, height: 14)
                            let actorColor = _journeyCGPaletteValue(config.actorColours, index: actorIdx, fallback: "#8FBC8F")
                            if let cgColor = _hexToCGColor(actorColor) {
                                ctx.setFillColor(cgColor)
                            } else {
                                ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                            }
                            ctx.fillEllipse(in: dotRect)
                            ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
                            ctx.setLineWidth(0.5)
                            ctx.strokeEllipse(in: dotRect)
                        }
                    }
                }

                // Dashed vertical guide line
                let lineCenterX = task.x + task.rectWidth / 2
                ctx.saveGState()
                ctx.setStrokeColor(self.theme.effectiveMuted().cgColor)
                ctx.setLineWidth(1)
                ctx.setLineDash(phase: 0, lengths: [4, 2])
                ctx.move(to: CGPoint(x: lineCenterX, y: task.y))
                ctx.addLine(to: CGPoint(x: lineCenterX, y: 450))
                ctx.strokePath()
                ctx.restoreGState()

                // Score face
                let faceCX = task.x + task.rectWidth / 2
                let faceCY = task.faceY
                let clampedScore = max(1, min(5, task.score))

                // Face circle
                let faceRect = CGRect(x: faceCX - 15, y: faceCY - 15, width: 30, height: 30)
                if let faceCGColor = _hexToCGColor(config.faceColor) {
                    ctx.setFillColor(faceCGColor)
                } else {
                    ctx.setFillColor(CGColor(red: 1.0, green: 0.97, blue: 0.85, alpha: 1.0))
                }
                ctx.fillEllipse(in: faceRect)
                ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                ctx.setLineWidth(2)
                ctx.strokeEllipse(in: faceRect)

                // Eyes
                let eyeColor = self.theme.effectiveMuted().cgColor
                ctx.setFillColor(eyeColor)
                ctx.setStrokeColor(eyeColor)
                ctx.setLineWidth(2)
                for dx in [-5.0, 5.0] {
                    let eyeRect = CGRect(x: faceCX + dx - 1.5, y: faceCY - 5 - 1.5, width: 3, height: 3)
                    ctx.fillEllipse(in: eyeRect)
                }

                // Mouth
                ctx.setLineWidth(clampedScore == 3 ? 1 : 2)
                if clampedScore > 3 {
                    let smileCenter = CGPoint(x: faceCX, y: faceCY + 2)
                    ctx.addArc(center: smileCenter, radius: 7.15, startAngle: .pi / 2, endAngle: 3 * .pi / 2, clockwise: false)
                } else if clampedScore < 3 {
                    let sadCenter = CGPoint(x: faceCX, y: faceCY + 7)
                    ctx.addArc(center: sadCenter, radius: 7.15, startAngle: 3 * .pi / 2, endAngle: .pi / 2, clockwise: false)
                } else {
                    ctx.move(to: CGPoint(x: faceCX - 5, y: faceCY + 7))
                    ctx.addLine(to: CGPoint(x: faceCX + 5, y: faceCY + 7))
                }
                ctx.strokePath()
            }

            // 4. Title
            if let title = journey.title, !title.isEmpty {
                let titleFontSize: CGFloat
                let sizeStr = config.titleFontSize
                let numericPart = sizeStr.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789.").inverted)
                if let parsed = Double(numericPart), parsed > 0 {
                    titleFontSize = CGFloat(parsed)
                } else {
                    titleFontSize = 18
                }
                let titleFont = BMFont.systemFont(ofSize: titleFontSize, weight: .bold)
                let titleColor: BMColor
                if !config.titleColor.isEmpty, let cg = _hexToCGColor(config.titleColor), let nsColor = BMColor(cgColor: cg) {
                    titleColor = nsColor
                } else {
                    titleColor = self.theme.foreground
                }
                self._drawTextInFlipped(
                    title,
                    at: CGPoint(x: journey.effectiveLeftMargin, y: 25),
                    context: ctx, contentHeight: ch,
                    color: titleColor,
                    font: titleFont,
                    alignment: .left
                )
            }

            // 5. Activity line with arrowhead
            let lineY = journey.activityLineY
            let lineX1 = journey.effectiveLeftMargin
            let lineX2 = journey.width - 4

            ctx.saveGState()
            ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
            ctx.setLineWidth(4)
            ctx.move(to: CGPoint(x: lineX1, y: lineY))
            ctx.addLine(to: CGPoint(x: lineX2, y: lineY))
            ctx.strokePath()

            // Arrowhead triangle
            ctx.setFillColor(self.theme.effectiveLine().cgColor)
            ctx.move(to: CGPoint(x: lineX2, y: lineY))
            ctx.addLine(to: CGPoint(x: lineX2 + 6, y: lineY - 2))
            ctx.addLine(to: CGPoint(x: lineX2 + 6, y: lineY + 2))
            ctx.closePath()
            ctx.fillPath()
            ctx.restoreGState()
        }
    }

    // MARK: - Color helpers

    private func _hexToCGColor(_ hex: String) -> CGColor? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        return CGColor(red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
                       green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
                       blue: CGFloat(rgb & 0xFF) / 255.0,
                       alpha: 1.0)
    }

    private func _hexToColor(_ hex: String) -> BMColor? {
        guard let cg = _hexToCGColor(hex) else { return nil }
        return BMColor(cgColor: cg)
    }

    private func _journeyCGPaletteValue(_ palette: [String], index: Int, fallback: String) -> String {
        guard !palette.isEmpty else { return fallback }
        return palette[index % palette.count]
    }
}
