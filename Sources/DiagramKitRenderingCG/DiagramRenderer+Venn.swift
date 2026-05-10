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
        let isHandDrawn = data.isHandDrawn
        let handDrawnSeed = data.handDrawnSeed

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

        for (i, area) in data.areas.enumerated() {
            _drawVennArea(area, areaIndex: i, in: context, isHandDrawn: isHandDrawn, handDrawnSeed: handDrawnSeed, debugLayout: data.useDebugLayout)
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

    private func _drawVennArea(_ area: PositionedVennArea, areaIndex: Int, in context: CGContext, isHandDrawn: Bool, handDrawnSeed: Int, debugLayout: Bool) {
        context.saveGState()

        // Draw circles for single-set areas
        for (ci, circle) in area.circles.enumerated() {
            let cx = CGFloat(circle.center.x)
            let cy = CGFloat(circle.center.y)
            let r = CGFloat(circle.radius)

            if isHandDrawn {
                let seed = handDrawnSeed + ci * 137
                let fillColor = BMColor(hex: area.fillColor).withAlphaComponent(CGFloat(area.fillOpacity))
                context.setFillColor(fillColor.cgColor)
                _drawHandDrawnCircleCG(cx: cx, cy: cy, r: r, seed: seed, in: context)

                let strokeColor = BMColor(hex: area.strokeColor).withAlphaComponent(0.95)
                context.setStrokeColor(strokeColor.cgColor)
                context.setLineWidth(CGFloat(area.strokeWidth))
                _drawHandDrawnCircleCG(cx: cx, cy: cy, r: r, seed: seed, in: context)
                context.strokePath()

                // Hachure fill
                let hachureAngle = -41.0 + Double(ci) * 60.0
                _drawHachureLinesCG(cx: cx, cy: cy, r: r * 0.95, seed: seed, angle: hachureAngle, gap: 8, in: context, color: BMColor(hex: area.fillColor).withAlphaComponent(0.4))
            } else {
                let fillColor = BMColor(hex: area.fillColor).withAlphaComponent(CGFloat(area.fillOpacity))
                context.setFillColor(fillColor.cgColor)
                context.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))

                let strokeColor = BMColor(hex: area.strokeColor).withAlphaComponent(0.95)
                context.setStrokeColor(strokeColor.cgColor)
                context.setLineWidth(CGFloat(area.strokeWidth))
                context.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            }

            if debugLayout {
                context.setStrokeColor(BMColor(hex: "#800080").cgColor)
                context.setLineWidth(1)
                context.setLineDash(phase: 0, lengths: [4, 2])
                context.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
                context.setLineDash(phase: 0, lengths: [])
            }
        }

        // Draw intersection path
        if let pathSpec = area.pathSpec, area.sets.count >= 2 {
            let path = _makeVennCGPath(from: pathSpec)
            if let path = path {
                if isHandDrawn && area.fillOpacity > 0 && area.fillColor.lowercased() != "transparent" {
                    _drawHandDrawnIntersectionCG(path: path, fillColor: BMColor(hex: area.fillColor), strokeColor: BMColor(hex: area.strokeColor), strokeWidth: CGFloat(area.strokeWidth), seed: handDrawnSeed, in: context)
                } else {
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
        }

        // Draw label
        let labelText = area.label ?? area.sets.first ?? ""
        if !labelText.isEmpty {
            let font = _systemFont(size: CGFloat(area.textFontSize))
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
        let fontSize: CGFloat = CGFloat(node.fontSize)
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
        DiagramFontResolver.proportional(config, size: size, weight: .regular)
    }

    // MARK: - Hand-Drawn CG Helpers

    private func _drawHandDrawnCircleCG(cx: CGFloat, cy: CGFloat, r: CGFloat, seed: Int, in context: CGContext) {
        let segments = 36
        var s = seed
        func nextJitter() -> CGFloat {
            s += 1
            var t = UInt64(bitPattern: Int64(s))
            t ^= t >> 12
            t ^= t << 25
            t ^= t >> 27
            let v = Double((t &* 2685821657736338717) & 0x7FFFFFFF) / Double(0x7FFFFFFF)
            return CGFloat((v - 0.5) * 0.06) * r
        }

        let path = CGMutablePath()
        for i in 0..<segments {
            let angle = 2.0 * .pi * Double(i) / Double(segments)
            let jx = cx + cos(CGFloat(angle)) * (r + nextJitter())
            let jy = cy + sin(CGFloat(angle)) * (r + nextJitter())
            if i == 0 {
                path.move(to: CGPoint(x: jx, y: jy))
            } else {
                path.addLine(to: CGPoint(x: jx, y: jy))
            }
        }
        path.closeSubpath()
        context.addPath(path)
    }

    private func _drawHachureLinesCG(cx: CGFloat, cy: CGFloat, r: CGFloat, seed: Int, angle: Double, gap: Double, in context: CGContext, color: BMColor) {
        let rad = CGFloat(angle * .pi / 180.0)
        let cosA = cos(rad)
        let sinA = sin(rad)
        let spacing = max(CGFloat(gap), 2)
        var s = seed

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.0)

        for offset in stride(from: -r * 1.5, through: r * 1.5, by: spacing) {
            s += 1
            var t = UInt64(bitPattern: Int64(s))
            t ^= t >> 12
            t ^= t << 25
            t ^= t >> 27
            let v = Double((t &* 2685821657736338717) & 0x7FFFFFFF) / Double(0x7FFFFFFF)
            let jitter = CGFloat((v - 0.5) * 0.3) * spacing

            let px = cx - r * 1.5 * cosA + (offset + jitter) * cosA
            let py = cy - r * 1.5 * sinA + (offset + jitter) * sinA

            let dx0 = px - cx
            let dy0 = py - cy
            let a: CGFloat = 1.0
            let b: CGFloat = 2 * (dx0 * sinA - dy0 * cosA)
            let c: CGFloat = dx0 * dx0 + dy0 * dy0 - r * r

            let discriminant = b * b - 4 * a * c
            if discriminant <= 0 { continue }

            let sqrtD = sqrt(discriminant)
            let t1 = (-b - sqrtD) / (2 * a)
            let t2 = (-b + sqrtD) / (2 * a)

            let x1 = px + t1 * sinA
            let y1 = py - t1 * cosA
            let x2 = px + t2 * sinA
            let y2 = py - t2 * cosA

            context.move(to: CGPoint(x: x1, y: y1))
            context.addLine(to: CGPoint(x: x2, y: y2))
        }
        context.strokePath()
    }

    private func _drawHandDrawnIntersectionCG(path: CGPath, fillColor: BMColor, strokeColor: BMColor, strokeWidth: CGFloat, seed: Int, in context: CGContext) {
        // Cross-hatch: two angles
        let bounds = path.boundingBoxOfPath
        let cx = bounds.midX
        let cy = bounds.midY
        let r = max(bounds.width, bounds.height) / 2 * 0.9

        _drawHachureLinesCG(cx: cx, cy: cy, r: r, seed: seed, angle: 45, gap: 6, in: context, color: fillColor.withAlphaComponent(0.6))
        _drawHachureLinesCG(cx: cx, cy: cy, r: r, seed: seed + 100, angle: -45, gap: 6, in: context, color: fillColor.withAlphaComponent(0.4))

        // Stroke outline
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth)
        context.addPath(path)
        context.strokePath()
    }
}
#endif
