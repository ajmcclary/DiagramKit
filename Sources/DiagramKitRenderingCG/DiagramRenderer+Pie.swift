import Foundation
import DiagramKitModel
import CoreGraphics
import CoreText
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension DiagramRenderer {

    func _drawPie(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case .pie(let chart) = positioned.content else { return }

        _withFittedContext(context, bounds: bounds, contentWidth: chart.width, contentHeight: chart.height) { ctx in

            ctx.translateBy(x: CGFloat(-chart.viewBoxX), y: 0)

            let pieCx: CGFloat = 225
            let pieCy: CGFloat = 225

            let opacity = CGFloat(Double(chart.theme.pieOpacity.replacingOccurrences(of: "}", with: "").trimmingCharacters(in: CharacterSet(charactersIn: ";"))) ?? 0.7)
            let strokeWidth = parsePieCGFloat(chart.theme.pieStrokeWidth) ?? 2

            let basePrimary = theme.accent?.hexString ?? "#ECECFF"
            let baseSecondary = PieChartThemeConfig.adjustHSL(basePrimary, hShift: 60, lShift: -10)
            let baseTertiary = PieChartThemeConfig.adjustHSL(basePrimary, hShift: -60, lShift: -10)

            let outerStrokeWidth = parsePieCGFloat(chart.theme.pieOuterStrokeWidth) ?? 2
            // Outer circle
            let outerR = CGFloat(chart.outerCircle.r)
            ctx.setStrokeColor(_pieColor(chart.theme.pieOuterStrokeColor, fallback: theme.effectiveLine()).cgColor)
            ctx.setLineWidth(outerStrokeWidth)
            ctx.addArc(center: CGPoint(x: pieCx, y: pieCy), radius: outerR, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
            ctx.strokePath()

            // Pie arcs
            for arc in chart.arcs {
                let colorIndex = arc.fillColorIndex
                let resolvedColor = _pieSliceColor(index: colorIndex, theme: chart.theme, primary: basePrimary, secondary: baseSecondary, tertiary: baseTertiary)
                ctx.setFillColor(resolvedColor.withAlphaComponent(opacity).cgColor)
                ctx.setStrokeColor(_pieColor(chart.theme.pieStrokeColor, fallback: resolvedColor).cgColor)
                ctx.setLineWidth(strokeWidth)

                _drawPieArc(ctx: ctx, cx: pieCx, cy: pieCy, r: pieChartRadius(for: chart, outerStrokeWidth: outerStrokeWidth), startAngle: CGFloat(arc.startAngle), endAngle: CGFloat(arc.endAngle))
                ctx.drawPath(using: .fillStroke)
            }

            let pieHeight: CGFloat = 450

            // Slice labels
            for label in chart.sliceLabels {
                let labelX = pieCx + CGFloat(label.x)
                let labelY = pieCy + CGFloat(label.y)
                _drawTextInFlipped(
                    label.text,
                    at: CGPoint(x: labelX, y: labelY),
                    context: ctx,
                    contentHeight: pieHeight,
                    color: _pieColor(chart.theme.resolvedPieSectionTextColor, fallback: theme.foreground),
                    font: _pieFont(size: parsePieCGFloat(chart.theme.pieSectionTextSize) ?? 17)
                )
            }

            // Title
            if let title = chart.title {
                let titleX = pieCx + CGFloat(title.x)
                let titleY = pieCy + CGFloat(title.y)
                _drawTextInFlipped(
                    title.text,
                    at: CGPoint(x: titleX, y: titleY),
                    context: ctx,
                    contentHeight: pieHeight,
                    color: _pieColor(chart.theme.resolvedPieTitleTextColor, fallback: theme.foreground),
                    font: _pieFont(size: parsePieCGFloat(chart.theme.pieTitleTextSize) ?? 25)
                )
            }

            // Legend
            for entry in chart.legend {
                let entryX = pieCx + CGFloat(entry.x)
                let entryY = pieCy + CGFloat(entry.y)
                let swatchY = entryY + CGFloat(entry.swatchY)

                let colorIndex = entry.colorIndex
                let resolvedColor = _pieSliceColor(index: colorIndex, theme: chart.theme, primary: basePrimary, secondary: baseSecondary, tertiary: baseTertiary)

                let swatchRect = CGRect(
                    x: entryX + CGFloat(entry.swatchX),
                    y: swatchY,
                    width: 18,
                    height: 18
                )
                ctx.setFillColor(resolvedColor.cgColor)
                ctx.fill(swatchRect)

                let textX = entryX + CGFloat(entry.swatchX) + 22
                let textY = swatchY + 14
                _drawTextInFlipped(
                    entry.displayText,
                    at: CGPoint(x: textX, y: textY),
                    context: ctx,
                    contentHeight: pieHeight,
                    color: _pieColor(chart.theme.resolvedPieLegendTextColor, fallback: theme.foreground),
                    font: _pieFont(size: parsePieCGFloat(chart.theme.pieLegendTextSize) ?? 17),
                    alignment: .left
                )
            }
        }
    }

    private func _drawPieArc(ctx: CGContext, cx: CGFloat, cy: CGFloat, r: CGFloat, startAngle: CGFloat, endAngle: CGFloat) {
        ctx.move(to: CGPoint(x: cx, y: cy))
        ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        ctx.closePath()
    }

    private func _pieSliceColor(index: Int, theme: PieChartThemeConfig, primary: String, secondary: String, tertiary: String) -> BMColor {
        BMColor(hex: theme.resolvedPieColor(at: index, primary: primary, secondary: secondary, tertiary: tertiary))
    }

    private func _pieColor(_ raw: String, fallback: BMColor) -> BMColor {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else {
            return trimmed.lowercased() == "black" ? BMColor.black : fallback
        }
        return BMColor(hex: trimmed)
    }
}

// MARK: - Helpers

private func parsePieCGFloat(_ s: String) -> CGFloat? {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    let numeric = trimmed
        .replacingOccurrences(of: "px", with: "")
        .replacingOccurrences(of: "em", with: "")
        .replacingOccurrences(of: "rem", with: "")
        .replacingOccurrences(of: "pt", with: "")
        .trimmingCharacters(in: .whitespaces)
    guard let value = Double(numeric) else { return nil }
    return CGFloat(value)
}

private func pieChartRadius(for chart: PositionedPieChart, outerStrokeWidth: CGFloat) -> CGFloat {
    max(0, CGFloat(chart.outerCircle.r) - outerStrokeWidth / 2)
}

private func _pieFont(size: CGFloat) -> BMFont {
    #if targetEnvironment(macCatalyst) || canImport(UIKit)
    return UIFont.systemFont(ofSize: size)
    #elseif canImport(AppKit)
    return NSFont.systemFont(ofSize: size)
    #endif
}
