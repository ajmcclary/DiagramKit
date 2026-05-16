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
    func _drawTreeView(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .treeView(data) = positioned.content else { return }
        let theme = self.theme

        if !theme.transparent {
            context.setFillColor(theme.background.cgColor)
            context.fill(bounds)
        }

        let cw = max(1.0, data.viewBoxWidth)
        let ch = max(1.0, data.viewBoxHeight)
        let scale = min(bounds.width / cw, bounds.height / ch)
        let offsetX = (bounds.width - cw * scale) / 2
        let offsetY = (bounds.height - ch * scale) / 2

        context.saveGState()
        context.translateBy(x: offsetX, y: offsetY)
        context.scaleBy(x: scale, y: scale)

        let tvTheme = data.theme ?? .default
        let labelFontSize = _tvParseLabelFontSize(tvTheme.labelFontSize)
        let labelFont = _tvFont(size: CGFloat(labelFontSize))
        let descFont = _tvItalicFont(size: CGFloat(labelFontSize))
        let labelColor = _tvColor(tvTheme.labelColor, fallback: theme.foreground)
        let lineColor = _tvColor(tvTheme.lineColor, fallback: theme.effectiveLine())
        let iconColor = _tvColor(tvTheme.iconColor, fallback: theme.effectiveAccent())
        let descColor = _tvColor(tvTheme.descriptionColor, fallback: theme.effectiveMuted())
        let highlightBg = _tvColor(tvTheme.highlightBg, fallback: theme.effectiveAccent().withAlphaComponent(0.15))
        let highlightStroke = _tvColor(tvTheme.highlightStroke, fallback: theme.effectiveAccent())

        for rect in data.highlightRects {
            context.setFillColor(highlightBg.cgColor)
            context.fill(CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height))
            context.setStrokeColor(highlightStroke.cgColor)
            context.setLineWidth(1)
            context.stroke(CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height))
        }

        for line in data.connectorLines {
            context.setStrokeColor(lineColor.cgColor)
            context.setLineWidth(CGFloat(data.config.lineThickness))
            context.move(to: CGPoint(x: line.x1, y: line.y1))
            context.addLine(to: CGPoint(x: line.x2, y: line.y2))
            context.strokePath()
        }

        for posNode in data.nodes {
            if let iconId = posNode.iconId, iconId != "none",
               let iconX = posNode.iconX, let iconY = posNode.iconY {
                let path = getIconPath(iconId: iconId)
                context.saveGState()
                let scale: Double = ICON_SIZE / 24.0
                context.translateBy(x: CGFloat(iconX), y: CGFloat(iconY))
                context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
                _drawSVGPath(path, in: context, color: iconColor)
                context.restoreGState()
            }

            let labelPoint = CGPoint(x: posNode.labelX, y: posNode.labelY)
            _drawTextInFlipped(posNode.name, at: labelPoint, context: context, contentHeight: CGFloat(data.viewBoxHeight), color: labelColor, font: labelFont, alignment: .left)

            if let desc = posNode.description, !desc.isEmpty,
               let descX = posNode.descriptionX, let descY = posNode.descriptionY {
                let descPoint = CGPoint(x: descX, y: descY)
                _drawTextInFlipped(desc, at: descPoint, context: context, contentHeight: CGFloat(data.viewBoxHeight), color: descColor, font: descFont, alignment: .left)
            }
        }

        context.restoreGState()
    }

    private func _tvParseLabelFontSize(_ value: String) -> Double {
        let cleaned = value.replacingOccurrences(of: "px", with: "").replacingOccurrences(of: "pt", with: "")
        return Double(cleaned) ?? 16
    }

    private func _tvFont(size: CGFloat) -> BMFont {
        self.fontResolver.proportionalFont(size: size, weight: .regular)
    }

    private func _tvItalicFont(size: CGFloat) -> BMFont {
        let baseFont = self.fontResolver.proportionalFont(size: size, weight: .regular)
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) {
            return BMFont(descriptor: descriptor, size: 0)
        }
        return baseFont
        #elseif canImport(AppKit)
        let manager = NSFontManager.shared
        return manager.convert(baseFont, toHaveTrait: .italicFontMask)
        #endif
    }

    private func _tvColor(_ value: String, fallback: BMColor) -> BMColor {
        DiagramColorParser.color(value) ?? fallback
    }

    private func _drawSVGPath(_ d: String, in context: CGContext, color: BMColor) {
        let path = _makeTreeViewCGPath(from: d)
        context.setFillColor(color.cgColor)
        context.addPath(path)
        context.fillPath()
    }

    private func _makeTreeViewCGPath(from d: String) -> CGPath {
        let path = CGMutablePath()
        let tokens = _tokenizeSVGPath(d)
        var index = 0
        var command: Character?
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastCubicControl: CGPoint?
        var previousCommand: Character?

        func commandToken(_ token: String) -> Character? {
            guard token.count == 1, let first = token.first, first.isLetter else { return nil }
            return first
        }

        func hasNumbers(_ count: Int) -> Bool {
            guard index + count <= tokens.count else { return false }
            return !tokens[index..<(index + count)].contains { commandToken($0) != nil }
        }

        func number() -> CGFloat {
            defer { index += 1 }
            return CGFloat(Double(tokens[index]) ?? 0)
        }

        func point(_ x: CGFloat, _ y: CGFloat, relative: Bool) -> CGPoint {
            relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
        }

        while index < tokens.count {
            if let cmd = commandToken(tokens[index]) {
                command = cmd
                index += 1
            }

            guard let cmd = command else {
                index += 1
                continue
            }

            let relative = cmd.isLowercase
            switch cmd {
            case "M", "m":
                var firstPoint = true
                while hasNumbers(2) {
                    let next = point(number(), number(), relative: relative)
                    if firstPoint {
                        path.move(to: next)
                        subpathStart = next
                        firstPoint = false
                    } else {
                        path.addLine(to: next)
                    }
                    current = next
                    previousCommand = cmd
                    lastCubicControl = nil
                }
                command = relative ? "l" : "L"

            case "L", "l":
                while hasNumbers(2) {
                    let next = point(number(), number(), relative: relative)
                    path.addLine(to: next)
                    current = next
                    previousCommand = cmd
                    lastCubicControl = nil
                }

            case "H", "h":
                while hasNumbers(1) {
                    let x = number()
                    let next = CGPoint(x: relative ? current.x + x : x, y: current.y)
                    path.addLine(to: next)
                    current = next
                    previousCommand = cmd
                    lastCubicControl = nil
                }

            case "V", "v":
                while hasNumbers(1) {
                    let y = number()
                    let next = CGPoint(x: current.x, y: relative ? current.y + y : y)
                    path.addLine(to: next)
                    current = next
                    previousCommand = cmd
                    lastCubicControl = nil
                }

            case "C", "c":
                while hasNumbers(6) {
                    let cp1 = point(number(), number(), relative: relative)
                    let cp2 = point(number(), number(), relative: relative)
                    let end = point(number(), number(), relative: relative)
                    path.addCurve(to: end, control1: cp1, control2: cp2)
                    current = end
                    lastCubicControl = cp2
                    previousCommand = cmd
                }

            case "S", "s":
                while hasNumbers(4) {
                    let prior = previousCommand.map { String($0).uppercased() }
                    let cp1: CGPoint
                    if (prior == "C" || prior == "S"), let lastCubicControl {
                        cp1 = CGPoint(x: 2 * current.x - lastCubicControl.x, y: 2 * current.y - lastCubicControl.y)
                    } else {
                        cp1 = current
                    }
                    let cp2 = point(number(), number(), relative: relative)
                    let end = point(number(), number(), relative: relative)
                    path.addCurve(to: end, control1: cp1, control2: cp2)
                    current = end
                    lastCubicControl = cp2
                    previousCommand = cmd
                }

            case "A", "a":
                while hasNumbers(7) {
                    let rx = abs(number())
                    let ry = abs(number())
                    _ = number()
                    let largeArc = number() != 0
                    let sweep = number() != 0
                    let end = point(number(), number(), relative: relative)
                    _addTreeViewSvgArc(
                        to: path,
                        from: current,
                        to: end,
                        radius: max(rx, ry),
                        largeArc: largeArc,
                        sweep: sweep
                    )
                    current = end
                    previousCommand = cmd
                    lastCubicControl = nil
                }

            case "Z", "z":
                path.closeSubpath()
                current = subpathStart
                previousCommand = cmd
                lastCubicControl = nil

            default:
                if !hasNumbers(1) {
                    index += 1
                }
            }
        }

        return path
    }

    private func _tokenizeSVGPath(_ d: String) -> [String] {
        let pattern = #"[A-Za-z]|[-+]?(?:(?:\d*\.\d+)|(?:\d+\.?))(?:[eE][-+]?\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(d.startIndex..<d.endIndex, in: d)
        return regex.matches(in: d, range: range).compactMap { match in
            guard let range = Range(match.range, in: d) else { return nil }
            return String(d[range])
        }
    }

    private func _addTreeViewSvgArc(
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
        let h = sqrt(max(0, adjustedRadius * adjustedRadius - chord * chord / 4))
        let nx = -dy / chord
        let ny = dx / chord
        let centers = [
            CGPoint(x: mid.x + nx * h, y: mid.y + ny * h),
            CGPoint(x: mid.x - nx * h, y: mid.y - ny * h),
        ]

        var selected = centers[0]
        for center in centers {
            let startAngle = atan2(start.y - center.y, start.x - center.x)
            let endAngle = atan2(end.y - center.y, end.x - center.x)
            var delta = endAngle - startAngle
            if sweep && delta < 0 { delta += 2 * .pi }
            if !sweep && delta > 0 { delta -= 2 * .pi }
            if (abs(delta) > .pi) == largeArc {
                selected = center
                break
            }
        }

        let startAngle = atan2(start.y - selected.y, start.x - selected.x)
        let endAngle = atan2(end.y - selected.y, end.x - selected.x)
        path.addArc(
            center: selected,
            radius: adjustedRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: !sweep
        )
    }
}
#endif
