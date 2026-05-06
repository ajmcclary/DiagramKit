import Foundation
import CoreGraphics
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension DiagramRenderer {
    func _drawMindmap(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .mindmap(data) = positioned.content else { return }

        if !theme.transparent {
            context.setFillColor(theme.background.cgColor)
            context.fill(bounds)
        }

        let bw = data.width
        let bh = data.height
        guard bw > 0, bh > 0 else { return }

        let scale = min(bounds.width / CGFloat(bw), bounds.height / CGFloat(bh))
        let ox = bounds.minX + (bounds.width - CGFloat(bw) * scale) / 2
        let oy = bounds.minY + (bounds.height - CGFloat(bh) * scale) / 2

        context.saveGState()
        context.translateBy(x: ox, y: oy)
        context.scaleBy(x: scale, y: scale)

        for edge in data.edges {
            _drawMindmapEdge(edge, context: context, theme: data.theme, config: data.config)
        }

        for node in data.nodes {
            _drawMindmapNodeShape(node, context: context, theme: data.theme, config: data.config)
            _drawMindmapNodeText(node, context: context, theme: data.theme, config: data.config)
            if let icon = node.icon {
                _drawMindmapIcon(node, icon: icon, context: context, theme: data.theme)
            }
        }

        context.restoreGState()
    }

    private func _drawMindmapEdge(_ edge: PositionedMindmapEdge, context: CGContext, theme: MindmapThemeConfig, config: MindmapConfig) {
        guard !edge.points.isEmpty else { return }
        let section = edge.section ?? 0
        let color = _cgColor(from: theme.cScale(for: section))
        let isNeo = config.look == "neo"
        let depth = edge.depth
        let sw: CGFloat = isNeo ? max(10 - CGFloat(depth - 1) * 2, 2) : max(17 - 3 * CGFloat(depth), 2)

        context.setStrokeColor(color)
        context.setLineWidth(sw)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        guard let first = edge.points.first else { return }
        context.move(to: first)
        for point in edge.points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()
    }

    private func _drawMindmapNodeShape(_ node: PositionedMindmapNode, context: CGContext, theme: MindmapThemeConfig, config: MindmapConfig) {
        let x = node.x - node.width / 2
        let y = node.y - node.height / 2
        let w = node.width
        let h = node.height
        let rect = CGRect(x: x, y: y, width: w, height: h)
        let fill = node.isRoot ? theme.git0 : theme.cScale(for: node.section ?? 0)
        let stroke = theme.nodeBorder
        let fillColor = _cgColor(from: fill)
        let strokeColor = _cgColor(from: stroke)
        let isNeo = config.look == "neo"

        context.setFillColor(fillColor)
        context.setStrokeColor(strokeColor)
        context.setLineWidth(CGFloat(theme.strokeWidth))

        switch node.type {
        case .default:
            if isNeo {
                let path = CGMutablePath()
                let r: CGFloat = 10
                path.move(to: CGPoint(x: x, y: y + r))
                path.addArc(tangent1End: CGPoint(x: x, y: y), tangent2End: CGPoint(x: x + r, y: y), radius: r)
                path.addLine(to: CGPoint(x: x + w - r, y: y))
                path.addArc(tangent1End: CGPoint(x: x + w, y: y), tangent2End: CGPoint(x: x + w, y: y + r), radius: r)
                path.addLine(to: CGPoint(x: x + w, y: y + h))
                path.addLine(to: CGPoint(x: x, y: y + h))
                path.closeSubpath()
                context.addPath(path)
                context.drawPath(using: .fillStroke)
            } else if node.isRoot {
                _addRoundedRectToContext(context, rect: rect, radius: 5)
                context.drawPath(using: .fillStroke)

                let lineColor = _cgColor(from: node.section.map { theme.cScaleInv(for: $0) } ?? theme.cScaleInv0)
                context.setStrokeColor(lineColor)
                context.setLineWidth(2)
                context.move(to: CGPoint(x: x, y: y + h))
                context.addLine(to: CGPoint(x: x + w, y: y + h))
                context.strokePath()
            } else {
                let path = CGMutablePath()
                let r: CGFloat = 5
                path.move(to: CGPoint(x: x, y: y + h))
                path.addLine(to: CGPoint(x: x, y: y + r))
                path.addArc(tangent1End: CGPoint(x: x, y: y), tangent2End: CGPoint(x: x + r, y: y), radius: r)
                path.addLine(to: CGPoint(x: x + w - r, y: y))
                path.addArc(tangent1End: CGPoint(x: x + w, y: y), tangent2End: CGPoint(x: x + w, y: y + r), radius: r)
                path.addLine(to: CGPoint(x: x + w, y: y + h))
                path.closeSubpath()
                context.addPath(path)
                context.drawPath(using: .fill)

                let lineColor = _cgColor(from: node.section.map { theme.cScaleInv(for: $0) } ?? theme.cScaleInv0)
                context.setStrokeColor(lineColor)
                context.setLineWidth(2)
                context.move(to: CGPoint(x: x, y: y + h))
                context.addLine(to: CGPoint(x: x + w, y: y + h))
                context.strokePath()
            }

        case .rect:
            if isNeo {
                _addRoundedRectToContext(context, rect: rect, radius: 5)
            } else {
                context.addRect(rect)
            }
            context.drawPath(using: .fillStroke)

        case .roundedRect:
            _addRoundedRectToContext(context, rect: rect, radius: 15)
            context.drawPath(using: .fillStroke)

        case .circle:
            let r = w / 2
            let centerY = y + h / 2
            let centerRect = CGRect(x: x + w / 2 - r, y: centerY - r, width: r * 2, height: r * 2)
            context.addEllipse(in: centerRect)
            context.drawPath(using: .fillStroke)

        case .hexagon:
            let mh = h / 4
            context.beginPath()
            context.move(to: CGPoint(x: x + mh, y: y))
            context.addLine(to: CGPoint(x: x + w - mh, y: y))
            context.addLine(to: CGPoint(x: x + w, y: y + h / 2))
            context.addLine(to: CGPoint(x: x + w - mh, y: y + h))
            context.addLine(to: CGPoint(x: x + mh, y: y + h))
            context.addLine(to: CGPoint(x: x, y: y + h / 2))
            context.closePath()
            context.drawPath(using: .fillStroke)

        case .cloud:
            _drawCloudShape(rect: rect, context: context)
            context.drawPath(using: .fillStroke)

        case .bang:
            _drawBangShape(rect: rect, context: context)
            context.drawPath(using: .fillStroke)
        }
    }

    private func _drawCloudShape(rect: CGRect, context: CGContext) {
        let x = rect.origin.x
        let y = rect.origin.y
        let w = rect.size.width
        let h = rect.size.height

        context.beginPath()
        context.move(to: CGPoint(x: x + w * 0.3, y: y + h * 0.7))
        context.addCurve(to: CGPoint(x: x + w * 0.2, y: y + h * 0.25), control1: CGPoint(x: x + w * 0.1, y: y + h * 0.65), control2: CGPoint(x: x + w * 0.05, y: y + h * 0.4))
        context.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.15), control1: CGPoint(x: x + w * 0.05, y: y + h * 0.05), control2: CGPoint(x: x + w * 0.35, y: y + h * 0.0))
        context.addCurve(to: CGPoint(x: x + w * 0.85, y: y + h * 0.25), control1: CGPoint(x: x + w * 0.65, y: y + h * 0.0), control2: CGPoint(x: x + w * 0.85, y: y + h * 0.05))
        context.addCurve(to: CGPoint(x: x + w * 0.75, y: y + h * 0.65), control1: CGPoint(x: x + w * 0.95, y: y + h * 0.35), control2: CGPoint(x: x + w * 0.9, y: y + h * 0.55))
        context.addCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.85), control1: CGPoint(x: x + w * 0.85, y: y + h * 0.85), control2: CGPoint(x: x + w * 0.65, y: y + h * 0.95))
        context.addCurve(to: CGPoint(x: x + w * 0.3, y: y + h * 0.7), control1: CGPoint(x: x + w * 0.35, y: y + h * 0.95), control2: CGPoint(x: x + w * 0.15, y: y + h * 0.85))
        context.closePath()
    }

    private func _drawBangShape(rect: CGRect, context: CGContext) {
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2

        context.beginPath()
        for i in 0..<5 {
            let angle = CGFloat(i) * 2 * .pi / 5 - .pi / 2
            let nextAngle = angle + 2 * .pi / 5
            let x1 = cx + r * cos(angle)
            let y1 = cy + r * sin(angle)
            let x2 = cx + r * 0.55 * cos(angle + .pi / 10)
            let y2 = cy + r * 0.55 * sin(angle + .pi / 10)
            let x3 = cx + r * cos(nextAngle)
            let y3 = cy + r * sin(nextAngle)
            let x4 = cx + r * 0.55 * cos(nextAngle - .pi / 10)
            let y4 = cy + r * 0.55 * sin(nextAngle - .pi / 10)

            if i == 0 {
                context.move(to: CGPoint(x: x1, y: y1))
            }
            context.addCurve(to: CGPoint(x: x3, y: y3), control1: CGPoint(x: x2, y: y2), control2: CGPoint(x: x4, y: y4))
        }
        context.closePath()
    }

    private func _drawMindmapNodeText(_ node: PositionedMindmapNode, context: CGContext, theme: MindmapThemeConfig, config: MindmapConfig) {
        let fill = node.isRoot ? theme.gitBranchLabel0 : theme.cScaleLabel(for: node.section ?? 0)
        let font = BMFont(name: theme.fontFamily, size: CGFloat(theme.fontSize)) ?? BMFont.systemFont(ofSize: CGFloat(theme.fontSize))

        let x = node.x - node.width / 2
        let y = node.y - node.height / 2
        let w = node.width
        let h = node.height
        let textColor = _bmColor(from: fill)

        let hasIcon = node.icon != nil
        let isCircle = node.type == .circle

        let label = node.descr
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n")

        if label.contains("\n") {
            let lines = label.split(separator: "\n")
            let lineHeight = theme.fontSize * 1.3
            let totalH = Double(lines.count) * lineHeight
            let startY = y + (h - totalH) / 2 + theme.fontSize

            for (idx, line) in lines.enumerated() {
                let textX: CGFloat
                if hasIcon && !isCircle {
                    textX = x + w / 2 + 25
                } else {
                    textX = x + w / 2
                }
                let textY = startY + Double(idx) * lineHeight

                _drawTextInFlipped(
                    String(line),
                    at: CGPoint(x: textX, y: textY),
                    context: context,
                    contentHeight: CGFloat(h),
                    color: textColor,
                    font: font,
                    alignment: .center
                )
            }
        } else {
            let textX: CGFloat
            if hasIcon && !isCircle {
                textX = x + w / 2 + 25
            } else {
                textX = x + w / 2
            }
            let textY = y + h / 2 + theme.fontSize / 3

            _drawTextInFlipped(
                label,
                at: CGPoint(x: textX, y: textY),
                context: context,
                contentHeight: CGFloat(h),
                color: textColor,
                font: font,
                alignment: .center
            )
        }
    }

    private func _drawMindmapIcon(_ node: PositionedMindmapNode, icon: String, context: CGContext, theme: MindmapThemeConfig) {
        let x = node.x - node.width / 2
        let y = node.y - node.height / 2
        let h = node.height
        let isCircle = node.type == .circle

        let iconColor = _bmColor(from: theme.cScaleLabel(for: node.section ?? 0))
        let iconFont = BMFont.systemFont(ofSize: 12)

        let iconX: CGFloat
        let iconY: CGFloat
        if isCircle {
            iconX = node.x - 15
            iconY = y + 5
        } else {
            iconX = x + 12
            iconY = y + h / 2 - 10
        }

        let label = _iconPlaceholder(icon)
        _drawTextInFlipped(
            label,
            at: CGPoint(x: iconX, y: iconY),
            context: context,
            contentHeight: CGFloat(h),
            color: iconColor,
            font: iconFont,
            alignment: .left
        )
    }

    private func _iconPlaceholder(_ icon: String) -> String {
        if icon.contains("bomb") { return "\u{1F4A3}" }
        if icon.contains("book") { return "\u{1F4D6}" }
        if icon.contains("fire") { return "\u{1F525}" }
        if icon.contains("star") { return "\u{2B50}" }
        if icon.contains("heart") { return "\u{2764}" }
        if icon.contains("check") { return "\u{2705}" }
        if icon.contains("gear") || icon.contains("cog") { return "\u{2699}" }
        return "\u{1F517}"
    }

    private func _cgColor(from hex: String) -> CGColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        return CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    private func _addRoundedRectToContext(_ context: CGContext, rect: CGRect, radius: CGFloat) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + radius), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - radius, y: rect.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - radius), radius: radius)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + radius, y: rect.minY), radius: radius)
        path.closeSubpath()
        context.addPath(path)
    }

    private func _bmColor(from hex: String) -> BMColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
        #elseif canImport(AppKit)
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
        #endif
    }
}
