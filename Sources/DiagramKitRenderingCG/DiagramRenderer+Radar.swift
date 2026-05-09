// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
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

    func _drawRadar(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case .radar(let chart) = positioned.content else { return }

        let globalFg = _hex(theme.foreground) ?? "#27272A"
        let globalLine = theme.line.flatMap { _hex($0) }
        let effectiveTheme = chart.theme.withGlobalColors(fg: globalFg, line: globalLine)

        _withFittedContext(context, bounds: bounds, contentWidth: chart.width, contentHeight: chart.height) { ctx in
            ctx.saveGState()
            ctx.translateBy(x: CGFloat(chart.centerX), y: CGFloat(chart.centerY))

            for graticule in chart.graticules {
                switch graticule.type {
                case .circle:
                    if let r = graticule.radius {
                        let circleRect = CGRect(x: CGFloat(-r), y: CGFloat(-r), width: CGFloat(r * 2), height: CGFloat(r * 2))
                        ctx.setFillColor(BMColor(hex: effectiveTheme.graticuleColor).withAlphaComponent(CGFloat(effectiveTheme.graticuleOpacity)).cgColor)
                        ctx.fillEllipse(in: circleRect)
                        ctx.setStrokeColor(BMColor(hex: effectiveTheme.graticuleColor).withAlphaComponent(CGFloat(effectiveTheme.graticuleOpacity)).cgColor)
                        ctx.setLineWidth(CGFloat(effectiveTheme.graticuleStrokeWidth))
                        ctx.strokeEllipse(in: circleRect)
                    }
                case .polygon:
                    if let pts = graticule.points, !pts.isEmpty {
                        ctx.setFillColor(BMColor(hex: effectiveTheme.graticuleColor).withAlphaComponent(CGFloat(effectiveTheme.graticuleOpacity)).cgColor)
                        ctx.setStrokeColor(BMColor(hex: effectiveTheme.graticuleColor).withAlphaComponent(CGFloat(effectiveTheme.graticuleOpacity)).cgColor)
                        ctx.setLineWidth(CGFloat(effectiveTheme.graticuleStrokeWidth))
                        ctx.move(to: CGPoint(x: CGFloat(pts[0].x), y: CGFloat(pts[0].y)))
                        for pt in pts.dropFirst() {
                            ctx.addLine(to: CGPoint(x: CGFloat(pt.x), y: CGFloat(pt.y)))
                        }
                        ctx.closePath()
                        ctx.drawPath(using: .fillStroke)
                    }
                }
            }

            for line in chart.axisLines {
                ctx.setStrokeColor(BMColor(hex: effectiveTheme.axisColor).cgColor)
                ctx.setLineWidth(CGFloat(effectiveTheme.axisStrokeWidth))
                ctx.move(to: CGPoint(x: CGFloat(line.x1), y: CGFloat(line.y1)))
                ctx.addLine(to: CGPoint(x: CGFloat(line.x2), y: CGFloat(line.y2)))
                ctx.strokePath()
            }

            for label in chart.axisLabels {
                _drawTextInFlipped(
                    label.text,
                    at: CGPoint(x: CGFloat(label.x), y: CGFloat(label.y)),
                    context: ctx,
                    contentHeight: CGFloat(chart.height),
                    color: BMColor(hex: effectiveTheme.axisColor),
                    font: _radarFont(size: CGFloat(label.fontSize)),
                    alignment: .center
                )
            }

            for curve in chart.curves {
                let color = BMColor(hex: effectiveTheme.curveColor(at: curve.index))
                let fillColor = color.withAlphaComponent(CGFloat(effectiveTheme.curveOpacity))
                ctx.setStrokeColor(color.cgColor)
                ctx.setFillColor(fillColor.cgColor)
                ctx.setLineWidth(CGFloat(effectiveTheme.curveStrokeWidth))

                switch curve.type {
                case .circle:
                    if !curve.points.isEmpty {
                        let path = CGMutablePath()
                        path.move(to: CGPoint(x: CGFloat(curve.points[0].x), y: CGFloat(curve.points[0].y)))
                        for segment in curve.cubicSegments {
                            path.addCurve(
                                to: CGPoint(x: CGFloat(segment.end.x), y: CGFloat(segment.end.y)),
                                control1: CGPoint(x: CGFloat(segment.cp1.x), y: CGFloat(segment.cp1.y)),
                                control2: CGPoint(x: CGFloat(segment.cp2.x), y: CGFloat(segment.cp2.y))
                            )
                        }
                        path.closeSubpath()
                        ctx.addPath(path)
                        ctx.drawPath(using: .fillStroke)
                    }
                case .polygon:
                    if !curve.points.isEmpty {
                        ctx.move(to: CGPoint(x: CGFloat(curve.points[0].x), y: CGFloat(curve.points[0].y)))
                        for pt in curve.points.dropFirst() {
                            ctx.addLine(to: CGPoint(x: CGFloat(pt.x), y: CGFloat(pt.y)))
                        }
                        ctx.closePath()
                        ctx.drawPath(using: .fillStroke)
                    }
                }
            }

            if chart.showLegend {
                for item in chart.legendItems {
                    let color = BMColor(hex: effectiveTheme.curveColor(at: item.index))
                    let fillColor = color.withAlphaComponent(CGFloat(effectiveTheme.curveOpacity))

                    let boxRect = CGRect(
                        x: CGFloat(item.x),
                        y: CGFloat(item.y),
                        width: CGFloat(item.boxSize),
                        height: CGFloat(item.boxSize)
                    )
                    ctx.setFillColor(fillColor.cgColor)
                    ctx.setStrokeColor(color.cgColor)
                    ctx.fill(boxRect)
                    ctx.stroke(boxRect)

                    _drawTextInFlipped(
                        item.label,
                        at: CGPoint(x: CGFloat(item.x + item.boxSize + 4), y: CGFloat(item.y)),
                        context: ctx,
                        contentHeight: CGFloat(chart.height),
                        color: BMColor(hex: effectiveTheme.axisColor),
                        font: _radarFont(size: CGFloat(effectiveTheme.legendFontSize)),
                        alignment: .left
                    )
                }
            }

            ctx.restoreGState()

            if let title = chart.title {
                _drawTextInFlipped(
                    title.text,
                    at: CGPoint(x: CGFloat(chart.centerX + title.x), y: CGFloat(chart.centerY + title.y)),
                    context: ctx,
                    contentHeight: CGFloat(chart.height),
                    color: BMColor(hex: effectiveTheme.titleColor),
                    font: _radarFont(size: CGFloat(title.fontSize), bold: true),
                    alignment: .center
                )
            }
        }
    }

    private func _radarFont(size: CGFloat, bold: Bool = false) -> BMFont {
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        if bold {
            return BMFont.boldSystemFont(ofSize: size)
        }
        return BMFont.systemFont(ofSize: size)
        #elseif canImport(AppKit)
        if bold {
            return NSFont.boldSystemFont(ofSize: size)
        }
        return NSFont.systemFont(ofSize: size)
        #endif
    }
}
#endif
