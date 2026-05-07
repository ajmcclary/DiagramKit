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

func _makeVennCGPath(from svgPath: String) -> CGPath? {
    let commands = svgPath.split(separator: " ")
    let mutablePath = CGMutablePath()
    var currentPoint = CGPoint.zero
    var command: Character = "M"
    var args: [CGFloat] = []
    var hasPath = false

    for token in commands {
        let text = String(token)
        if text == "M" || text == "L" || text == "C" || text == "A" || text == "Z" {
            if !args.isEmpty {
                _applyVennPathCommand(command, args: args, currentPoint: &currentPoint, path: mutablePath)
                hasPath = true
                args = []
            }
            if text == "Z" {
                mutablePath.closeSubpath()
                hasPath = true
                continue
            }
            command = text.first!
        } else if let value = Double(text) {
            args.append(CGFloat(value))
        }
    }

    if !args.isEmpty {
        _applyVennPathCommand(command, args: args, currentPoint: &currentPoint, path: mutablePath)
        hasPath = true
    }

    return hasPath ? mutablePath : nil
}

private func _applyVennPathCommand(_ cmd: Character, args: [CGFloat], currentPoint: inout CGPoint, path: CGMutablePath) {
    switch cmd {
    case "M":
        guard args.count >= 2 else { return }
        let point = CGPoint(x: args[0], y: args[1])
        path.move(to: point)
        currentPoint = point
    case "L":
        guard args.count >= 2 else { return }
        let point = CGPoint(x: args[0], y: args[1])
        path.addLine(to: point)
        currentPoint = point
    case "C":
        guard args.count >= 6 else { return }
        let cp1 = CGPoint(x: args[0], y: args[1])
        let cp2 = CGPoint(x: args[2], y: args[3])
        let end = CGPoint(x: args[4], y: args[5])
        path.addCurve(to: end, control1: cp1, control2: cp2)
        currentPoint = end
    case "A":
        guard args.count >= 7 else { return }
        let rx = args[0]
        let ry = args[1]
        let largeArc = args[3] != 0
        let sweep = args[4] != 0
        let end = CGPoint(x: args[5], y: args[6])
        _addCircularSvgArc(
            to: path,
            from: currentPoint,
            to: end,
            radius: max(rx, ry),
            largeArc: largeArc,
            sweep: sweep
        )
        currentPoint = end
    default:
        break
    }
}

private func _addCircularSvgArc(
    to path: CGMutablePath,
    from start: CGPoint,
    to end: CGPoint,
    radius: CGFloat,
    largeArc: Bool,
    sweep: Bool
) {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let chord = hypot(dx, dy)
    guard radius > 0, chord > 0 else {
        path.addLine(to: end)
        return
    }

    let adjustedRadius = max(radius, chord / 2)
    let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    let h = sqrt(max(0, adjustedRadius * adjustedRadius - (chord * chord / 4)))
    let nx = -dy / chord
    let ny = dx / chord
    let candidates = [
        CGPoint(x: mid.x + nx * h, y: mid.y + ny * h),
        CGPoint(x: mid.x - nx * h, y: mid.y - ny * h)
    ]

    let selected = candidates.first { center in
        let startAngle = atan2(start.y - center.y, start.x - center.x)
        let endAngle = atan2(end.y - center.y, end.x - center.x)
        let delta = _svgArcDelta(startAngle: startAngle, endAngle: endAngle, sweep: sweep)
        return (abs(delta) > .pi) == largeArc
    } ?? candidates[0]

    let startAngle = atan2(start.y - selected.y, start.x - selected.x)
    let endAngle = atan2(end.y - selected.y, end.x - selected.x)
    let delta = _svgArcDelta(startAngle: startAngle, endAngle: endAngle, sweep: sweep)
    path.addArc(
        center: selected,
        radius: adjustedRadius,
        startAngle: startAngle,
        endAngle: startAngle + delta,
        clockwise: !sweep
    )
}

private func _svgArcDelta(startAngle: CGFloat, endAngle: CGFloat, sweep: Bool) -> CGFloat {
    var delta = endAngle - startAngle
    if sweep {
        while delta < 0 { delta += 2 * .pi }
    } else {
        while delta > 0 { delta -= 2 * .pi }
    }
    return delta
}

extension DiagramRenderer {
    func _drawVenn(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .venn(data) = positioned.content else { return }
        let theme = self.theme

        if !theme.transparent {
            context.setFillColor(theme.background.cgColor)
            context.fill(bounds)
        }

        let vennWidth = CGFloat(data.width)
        let vennHeight = CGFloat(data.height)
        let scale = min(bounds.width / vennWidth, bounds.height / vennHeight)
        let offsetX = (bounds.width - vennWidth * scale) / 2
        let offsetY = (bounds.height - vennHeight * scale) / 2

        context.saveGState()
        context.translateBy(x: offsetX, y: offsetY)
        context.scaleBy(x: scale, y: scale)

        if let title = data.title {
            _drawVennTitle(title, in: context)
        }

        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(data.titleHeight))

        for area in data.areas {
            _drawVennArea(area, in: context, debugLayout: data.useDebugLayout)
        }

        for node in data.textNodes {
            _drawVennTextNode(node, in: context, debugLayout: data.useDebugLayout)
        }

        context.restoreGState()

        context.restoreGState()
    }

    private func _drawVennTitle(_ title: PositionedVennTitle, in context: CGContext) {
        let font = _systemFont(size: CGFloat(title.fontSize))
        let color = BMColor(hex: title.fillColor)
        let point = CGPoint(x: CGFloat(title.x), y: CGFloat(title.y))
        _drawTextInFlipped(title.text, at: point, context: context, contentHeight: 1000, color: color, font: font, alignment: .center)
    }

    private func _drawVennArea(_ area: PositionedVennArea, in context: CGContext, debugLayout: Bool) {
        context.saveGState()

        // Draw circles for single-set areas
        for circle in area.circles {
            let cx = CGFloat(circle.center.x)
            let cy = CGFloat(circle.center.y)
            let r = CGFloat(circle.radius)

            let fillColor = BMColor(hex: area.fillColor).withAlphaComponent(CGFloat(area.fillOpacity))
            context.setFillColor(fillColor.cgColor)
            context.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))

            let strokeColor = BMColor(hex: area.strokeColor).withAlphaComponent(0.95)
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(CGFloat(area.strokeWidth))
            context.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))

            if debugLayout {
                context.setStrokeColor(BMColor(hex: "#800080").cgColor)
                context.setLineWidth(1)
                context.setLineDash(phase: 0, lengths: [4, 2])
                context.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
                context.setLineDash(phase: 0, lengths: [])
            }
        }

        // Draw intersection path
        if let pathSpec = area.pathSpec, !area.circles.isEmpty == false || area.sets.count >= 2 {
            let path = _makeVennCGPath(from: pathSpec)
            if let path = path {
                let fillColor = BMColor(hex: area.fillColor).withAlphaComponent(CGFloat(area.fillOpacity))
                context.setFillColor(fillColor.cgColor)
                context.addPath(path)
                context.fillPath()

                let strokeColor = BMColor(hex: area.strokeColor).withAlphaComponent(0.95)
                context.setStrokeColor(strokeColor.cgColor)
                context.setLineWidth(CGFloat(area.strokeWidth))
                context.addPath(path)
                context.strokePath()
            }
        }

        // Draw label
        let labelText = area.label ?? area.sets.first ?? ""
        if !labelText.isEmpty {
            let font: BMFont
            if area.isSingleSet {
                font = _systemFont(size: CGFloat(area.textFontSize))
            } else {
                font = _systemFont(size: CGFloat(area.textFontSize))
            }
            let textColor = BMColor(hex: area.textColor)
            let point = CGPoint(x: CGFloat(area.textPoint.x), y: CGFloat(area.textPoint.y))
            _drawTextInFlipped(labelText, at: point, context: context, contentHeight: 1000, color: textColor, font: font, alignment: .center)
        }

        context.restoreGState()
    }

    private func _drawVennTextNode(_ node: PositionedVennTextNode, in context: CGContext, debugLayout: Bool) {
        context.saveGState()

        let x = CGFloat(node.x)
        let y = CGFloat(node.y)
        let w = CGFloat(node.width)
        let h = CGFloat(node.height)
        let rect = CGRect(x: x, y: y, width: w, height: h)

        let displayText = node.label ?? node.id

        let textColor = BMColor(hex: node.textColor)
        let fontSize: CGFloat = 12
        let font = _systemFont(size: fontSize)

        labelRenderer.drawMultilineText(displayText, in: rect, context: context, color: textColor, font: font, alignment: .center)

        if debugLayout {
            let cx = x + w / 2
            let cy = y + h / 2
            context.setStrokeColor(BMColor(hex: "#800080").cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [3, 2])
            context.strokeEllipse(in: CGRect(x: cx - 5, y: cy - 5, width: 10, height: 10))
            context.setLineDash(phase: 0, lengths: [])
            context.setStrokeColor(BMColor(hex: "#008080").cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [3, 2])
            context.stroke(rect)
            context.setLineDash(phase: 0, lengths: [])
        }

        context.restoreGState()
    }

    private func _systemFont(size: CGFloat) -> BMFont {
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        return BMFont.systemFont(ofSize: size)
        #elseif canImport(AppKit)
        return BMFont.systemFont(ofSize: size)
        #endif
    }
}
