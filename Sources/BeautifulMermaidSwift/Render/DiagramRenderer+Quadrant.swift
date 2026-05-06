import Foundation
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

    func _drawQuadrant(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case .quadrantChart(let chart) = positioned.content else { return }

        _withFittedContext(context, bounds: bounds, contentWidth: chart.width, contentHeight: chart.height) { ctx in
            // Quadrant fills (rectangles)
            for quadrant in chart.quadrants {
                let rect = CGRect(
                    x: CGFloat(quadrant.x),
                    y: CGFloat(quadrant.y),
                    width: CGFloat(quadrant.width),
                    height: CGFloat(quadrant.height)
                )
                ctx.setFillColor(BMColor(hex: quadrant.fill).cgColor)
                ctx.fill(rect)
            }

            // Border lines
            for line in chart.borderLines {
                ctx.setStrokeColor(BMColor(hex: line.strokeFill).cgColor)
                ctx.setLineWidth(CGFloat(line.strokeWidth))
                ctx.move(to: CGPoint(x: CGFloat(line.x1), y: CGFloat(line.y1)))
                ctx.addLine(to: CGPoint(x: CGFloat(line.x2), y: CGFloat(line.y2)))
                ctx.strokePath()
            }

            // Axis labels (text)
            for label in chart.axisLabels {
                _drawQuadrantText(
                    label.text,
                    x: CGFloat(label.x),
                    y: CGFloat(label.y),
                    rotation: CGFloat(label.rotation),
                    fill: label.fill,
                    fontSize: CGFloat(label.fontSize),
                    horizontalPos: label.horizontalPos,
                    verticalPos: label.verticalPos,
                    context: ctx
                )
            }

            // Quadrant labels
            for quadrant in chart.quadrants {
                _drawQuadrantText(
                    quadrant.text.text,
                    x: CGFloat(quadrant.text.x),
                    y: CGFloat(quadrant.text.y),
                    rotation: CGFloat(quadrant.text.rotation),
                    fill: quadrant.text.fill,
                    fontSize: CGFloat(quadrant.text.fontSize),
                    horizontalPos: quadrant.text.horizontalPos,
                    verticalPos: quadrant.text.verticalPos,
                    context: ctx
                )
            }

            // Points
            for point in chart.points {
                let circleRect = CGRect(
                    x: CGFloat(point.x - point.radius),
                    y: CGFloat(point.y - point.radius),
                    width: CGFloat(point.radius * 2),
                    height: CGFloat(point.radius * 2)
                )
                ctx.setFillColor(BMColor(hex: point.fill).cgColor)
                ctx.setStrokeColor(BMColor(hex: point.strokeColor).cgColor)
                let sw = parseQuadrantCGFloat(point.strokeWidth) ?? 0
                ctx.setLineWidth(sw)
                ctx.addEllipse(in: circleRect)
                ctx.drawPath(using: .fillStroke)

                _drawQuadrantText(
                    point.text.text,
                    x: CGFloat(point.text.x),
                    y: CGFloat(point.text.y),
                    rotation: CGFloat(point.text.rotation),
                    fill: point.text.fill,
                    fontSize: CGFloat(point.text.fontSize),
                    horizontalPos: point.text.horizontalPos,
                    verticalPos: point.text.verticalPos,
                    context: ctx
                )
            }

            // Title
            if let title = chart.title {
                _drawQuadrantText(
                    title.text,
                    x: CGFloat(title.x),
                    y: CGFloat(title.y),
                    rotation: CGFloat(title.rotation),
                    fill: title.fill,
                    fontSize: CGFloat(title.fontSize),
                    horizontalPos: title.horizontalPos,
                    verticalPos: title.verticalPos,
                    context: ctx
                )
            }
        }
    }

    private func _drawQuadrantText(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        rotation: CGFloat,
        fill: String,
        fontSize: CGFloat,
        horizontalPos: String,
        verticalPos: String,
        context: CGContext
    ) {
        guard !text.isEmpty else { return }

        context.saveGState()

        context.translateBy(x: x, y: y)

        if rotation != 0 {
            context.rotate(by: rotation * .pi / 180)
        }

        let font = _quadrantFont(size: fontSize)
        let alignment: TextAlignment

        if verticalPos == "left" {
            alignment = .left
        } else if verticalPos == "right" {
            alignment = .right
        } else {
            alignment = .center
        }

        let labelRenderer = LabelRenderer()
        let point: CGPoint
        if horizontalPos == "top" {
            point = CGPoint(x: 0, y: fontSize / 2)
        } else {
            point = CGPoint.zero
        }
        labelRenderer.drawText(
            text,
            at: point,
            context: context,
            color: BMColor(hex: fill),
            font: font,
            alignment: alignment
        )

        context.restoreGState()
    }
}

// MARK: - Helpers

private func parseQuadrantCGFloat(_ s: String) -> CGFloat? {
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

private func _quadrantFont(size: CGFloat) -> BMFont {
    #if targetEnvironment(macCatalyst) || canImport(UIKit)
    return UIFont.systemFont(ofSize: size)
    #elseif canImport(AppKit)
    return NSFont.systemFont(ofSize: size)
    #endif
}
