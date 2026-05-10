// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import CoreGraphics
import DiagramKitCommon

extension DiagramRenderer {

    func _drawGantt(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .gantt(gantt) = positioned.content, !gantt.tasks.isEmpty else { return }

        _withFittedContext(context, bounds: bounds,
                           contentWidth: max(1, gantt.width),
                           contentHeight: max(1, gantt.height)) { ctx in
            let ch = max(1, gantt.height)
            let config = gantt.config

            let theme = GanttThemeVariables.default

            // 1. Excluded ranges
            for range in gantt.excludedRanges {
                if let cg = MermaidColorParser.cgHex(theme.excludeBkgColor) {
                    ctx.setFillColor(cg)
                } else {
                    ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                }
                ctx.fill(range.backgroundRect)
            }

            // 2. Grid lines and axis ticks
            let gridY = gantt.height - config.gridLineStartPadding
            let gridLineHeight = gantt.gridLineHeight > 0 ? gantt.gridLineHeight : config.gridLineStartPadding
            for tick in gantt.axisTicks {
                ctx.setStrokeColor(MermaidColorParser.cgHex(theme.gridColor) ?? self.theme.effectiveMuted().cgColor)
                ctx.setLineWidth(0.5)
                ctx.move(to: CGPoint(x: tick.x, y: gridY))
                ctx.addLine(to: CGPoint(x: tick.x, y: gridY + gridLineHeight))
                ctx.strokePath()

                let tickFont = DiagramFontResolver.proportional(self.config, size: 10, weight: .regular)
                self._drawTextInFlipped(
                    tick.label,
                    at: CGPoint(x: tick.x, y: gridY + 15),
                    context: ctx, contentHeight: ch,
                    color: self.theme.foreground,
                    font: tickFont,
                    alignment: .center
                )
            }

            // Top axis
            if let topTicks = gantt.topAxisTicks {
                let topGridLineHeight = gridLineHeight - config.topPadding + config.gridLineStartPadding
                for tick in topTicks {
                    ctx.setStrokeColor(MermaidColorParser.cgHex(theme.gridColor) ?? self.theme.effectiveMuted().cgColor)
                    ctx.setLineWidth(0.5)
                    ctx.move(to: CGPoint(x: tick.x, y: config.topPadding))
                    ctx.addLine(to: CGPoint(x: tick.x, y: config.topPadding + topGridLineHeight))
                    ctx.strokePath()

                    let tickFont = DiagramFontResolver.proportional(self.config, size: 10, weight: .regular)
                    self._drawTextInFlipped(
                        tick.label,
                        at: CGPoint(x: tick.x, y: config.topPadding + 15 + topGridLineHeight),
                        context: ctx, contentHeight: ch,
                        color: self.theme.foreground,
                        font: tickFont,
                        alignment: .center
                    )
                }
            }

            // 3. Section backgrounds
            for section in gantt.sections {
                let sectionRect = section.backgroundRect
                let fillColor: String
                switch section.styleIndex % 4 {
                case 0: fillColor = theme.sectionBkgColor
                case 1, 3: fillColor = theme.altSectionBkgColor
                case 2: fillColor = theme.sectionBkgColor2
                default: fillColor = theme.sectionBkgColor
                }
                if let cg = MermaidColorParser.cgHex(fillColor) {
                    ctx.setFillColor(cg)
                } else {
                    ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                }
                ctx.setAlpha(0.2)
                ctx.fill(sectionRect)
                ctx.setAlpha(1.0)
            }

            // 4. Task bars
            for ptask in gantt.tasks {
                let rect = ptask.barRect
                let isMilestone = ptask.task.tags.contains(.milestone)
                let isVert = ptask.task.tags.contains(.vert)

                if isVert {
                    if let cg = MermaidColorParser.cgHex(theme.vertLineColor) {
                        ctx.setFillColor(cg)
                    } else {
                        ctx.setFillColor(self.theme.effectiveLine().cgColor)
                    }
                    ctx.fill(rect)
                } else if isMilestone {
                    ctx.saveGState()
                    let cx = rect.midX
                    let cy = rect.midY
                    ctx.translateBy(x: cx, y: cy)
                    ctx.rotate(by: .pi / 4)
                    ctx.scaleBy(x: 0.8, y: 0.8)
                    let centeredRect = CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)

                    let fillHex: String
                    let strokeHex: String
                    if ptask.task.tags.contains(.done) && ptask.task.tags.contains(.crit) {
                        fillHex = theme.doneTaskBkgColor
                        strokeHex = theme.critBorderColor
                    } else if ptask.task.tags.contains(.active) && ptask.task.tags.contains(.crit) {
                        fillHex = theme.activeTaskBkgColor
                        strokeHex = theme.critBorderColor
                    } else if ptask.task.tags.contains(.active) {
                        fillHex = theme.activeTaskBkgColor
                        strokeHex = theme.activeTaskBorderColor
                    } else if ptask.task.tags.contains(.done) {
                        fillHex = theme.doneTaskBkgColor
                        strokeHex = theme.doneTaskBorderColor
                    } else if ptask.task.tags.contains(.crit) {
                        fillHex = theme.critBkgColor
                        strokeHex = theme.critBorderColor
                    } else {
                        fillHex = theme.taskBkgColor
                        strokeHex = theme.taskBorderColor
                    }

                    if let cg = MermaidColorParser.cgHex(fillHex) {
                        ctx.setFillColor(cg)
                    } else {
                        ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                    }
                    ctx.fill(centeredRect)

                    if let cg = MermaidColorParser.cgHex(strokeHex) {
                        ctx.setStrokeColor(cg)
                    } else {
                        ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
                    }
                    ctx.setLineWidth(1)
                    ctx.stroke(centeredRect)
                    ctx.restoreGState()
                } else {
                    let path = CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil)

                    let fillHex: String
                    let strokeHex: String
                    if ptask.task.tags.contains(.done) && ptask.task.tags.contains(.crit) {
                        fillHex = theme.doneTaskBkgColor
                        strokeHex = theme.critBorderColor
                    } else if ptask.task.tags.contains(.active) && ptask.task.tags.contains(.crit) {
                        fillHex = theme.activeTaskBkgColor
                        strokeHex = theme.critBorderColor
                    } else if ptask.task.tags.contains(.active) {
                        fillHex = theme.activeTaskBkgColor
                        strokeHex = theme.activeTaskBorderColor
                    } else if ptask.task.tags.contains(.done) {
                        fillHex = theme.doneTaskBkgColor
                        strokeHex = theme.doneTaskBorderColor
                    } else if ptask.task.tags.contains(.crit) {
                        fillHex = theme.critBkgColor
                        strokeHex = theme.critBorderColor
                    } else {
                        fillHex = theme.taskBkgColor
                        strokeHex = theme.taskBorderColor
                    }

                    if let cg = MermaidColorParser.cgHex(fillHex) {
                        ctx.setFillColor(cg)
                    } else {
                        ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                    }
                    ctx.addPath(path)
                    ctx.fillPath()

                    if let cg = MermaidColorParser.cgHex(strokeHex) {
                        ctx.setStrokeColor(cg)
                    } else {
                        ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
                    }
                    ctx.setLineWidth(1)
                    ctx.addPath(path)
                    ctx.strokePath()
                }

                // 5. Task labels
                let taskFont = DiagramFontResolver.proportional(self.config, size: CGFloat(config.fontSize), weight: .regular)
                let textColor: BMColor
                if ptask.labelClass.contains("taskTextOutsideLeft") || ptask.labelClass.contains("taskTextOutsideRight") {
                    textColor = MermaidColorParser.hexColor(theme.taskTextOutsideColor) ?? self.theme.foreground
                } else {
                    textColor = MermaidColorParser.hexColor(theme.taskTextColor) ?? self.theme.foreground
                }

                let alignment: TextAlignment
                if ptask.labelClass.contains("taskTextOutsideLeft") {
                    alignment = .right
                } else if ptask.labelClass.contains("taskTextOutsideRight") {
                    alignment = .left
                } else {
                    alignment = .center
                }

                self._drawTextInFlipped(
                    ptask.task.task,
                    at: ptask.labelPoint,
                    context: ctx, contentHeight: ch,
                    color: textColor,
                    font: taskFont,
                    alignment: alignment
                )
            }

            // 6. Section labels
            for section in gantt.sections {
                let lines = original_src_multiline_utils.normalizeBrTags(section.name).components(separatedBy: "\n")
                let sectionFont = DiagramFontResolver.proportional(self.config, size: CGFloat(config.sectionFontSize), weight: .bold)
                let lineHeight = config.sectionFontSize * 1.3
                let totalHeight = Double(lines.count) * lineHeight
                let startY = section.labelPoint.y - totalHeight / 2 + config.sectionFontSize

                for (li, line) in lines.enumerated() {
                    self._drawTextInFlipped(
                        line,
                        at: CGPoint(x: section.labelPoint.x, y: startY + Double(li) * lineHeight),
                        context: ctx, contentHeight: ch,
                        color: self.theme.foreground,
                        font: sectionFont,
                        alignment: .left
                    )
                }
            }

            // 7. Today marker
            if let todayX = gantt.todayLineX {
                ctx.setStrokeColor(MermaidColorParser.cgHex(theme.todayLineColor)?.copy(alpha: 0.8) ?? self.theme.effectiveAccent().cgColor)
                ctx.setLineWidth(2)
                ctx.move(to: CGPoint(x: todayX, y: config.titleTopMargin))
                ctx.addLine(to: CGPoint(x: todayX, y: gantt.height - config.titleTopMargin))
                ctx.strokePath()
            }

            // 8. Title
            if let title = gantt.title, !title.isEmpty {
                let titleFont = DiagramFontResolver.proportional(self.config, size: 18, weight: .bold)
                self._drawTextInFlipped(
                    title,
                    at: CGPoint(x: gantt.width / 2, y: config.titleTopMargin),
                    context: ctx, contentHeight: ch,
                    color: self.theme.foreground,
                    font: titleFont,
                    alignment: .center
                )
            }
        }
    }

    // MARK: - Color helpers

    // _hexToCGColor / _hexToColor → MermaidColorParser.cgHex(_:)
}
#endif
