// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
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

        // Mermaid cloud: arc-based bumpy contour starting at (0,0).
        // Approximated with bezier curves for Core Graphics parity.
        context.beginPath()
        context.move(to: CGPoint(x: x, y: y))
        // Top-right bump
        context.addCurve(to: CGPoint(x: x + w*0.65, y: y - h*0.05),
                         control1: CGPoint(x: x + w*0.15, y: y - h*0.18),
                         control2: CGPoint(x: x + w*0.4, y: y - h*0.15))
        // Top-center bump
        context.addCurve(to: CGPoint(x: x + w, y: y + h*0.2),
                         control1: CGPoint(x: x + w*0.82, y: y - h*0.05),
                         control2: CGPoint(x: x + w, y: y + h*0.05))
        // Right-upper bump
        context.addCurve(to: CGPoint(x: x + w*0.9, y: y + h*0.5),
                         control1: CGPoint(x: x + w, y: y + h*0.35),
                         control2: CGPoint(x: x + w*0.95, y: y + h*0.42))
        // Right-lower bump
        context.addCurve(to: CGPoint(x: x + w*0.7, y: y + h*0.85),
                         control1: CGPoint(x: x + w*0.85, y: y + h*0.65),
                         control2: CGPoint(x: x + w*0.78, y: y + h*0.78))
        // Bottom-right
        context.addCurve(to: CGPoint(x: x + w*0.4, y: y + h),
                         control1: CGPoint(x: x + w*0.58, y: y + h*0.95),
                         control2: CGPoint(x: x + w*0.48, y: y + h))
        // Bottom-left
        context.addCurve(to: CGPoint(x: x + w*0.1, y: y + h*0.8),
                         control1: CGPoint(x: x + w*0.25, y: y + h), control2: CGPoint(x: x + w*0.15, y: y + h*0.9))
        // Left-lower
        context.addCurve(to: CGPoint(x: x - w*0.05, y: y + h*0.45),
                         control1: CGPoint(x: x + w*0.02, y: y + h*0.65), control2: CGPoint(x: x - w*0.05, y: y + h*0.55))
        // Left-upper
        context.addCurve(to: CGPoint(x: x, y: y + h*0.15),
                         control1: CGPoint(x: x - w*0.05, y: y + h*0.3), control2: CGPoint(x: x - w*0.02, y: y + h*0.2))
        // Top-left back to origin
        context.addCurve(to: CGPoint(x: x, y: y),
                         control1: CGPoint(x: x + w*0.05, y: y + h*0.08), control2: CGPoint(x: x + w*0.02, y: y + h*0.03))
        context.closePath()
    }

    private func _drawBangShape(rect: CGRect, context: CGContext) {
        let x = rect.origin.x
        let y = rect.origin.y
        let w = rect.size.width
        let h = rect.size.height

        // Mermaid bang: arc-based exclamation silhouette starting at (0,0).
        // Approximated with curves for Core Graphics.
        context.beginPath()
        context.move(to: CGPoint(x: x, y: y))
        // Top section: flared outward from center, narrowing to middle pinch
        context.addCurve(to: CGPoint(x: x + w*0.25, y: y - h*0.05), control1: CGPoint(x: x + w*0.05, y: y - h*0.05), control2: CGPoint(x: x + w*0.15, y: y - h*0.08))
        context.addCurve(to: CGPoint(x: x + w*0.5, y: y + h*0.05), control1: CGPoint(x: x + w*0.38, y: y), control2: CGPoint(x: x + w*0.45, y: y + h*0.02))
        context.addCurve(to: CGPoint(x: x + w*0.75, y: y + h*0.0), control1: CGPoint(x: x + w*0.6, y: y + h*0.05), control2: CGPoint(x: x + w*0.68, y: y + h*0.02))
        context.addCurve(to: CGPoint(x: x + w, y: y + h*0.1), control1: CGPoint(x: x + w*0.85, y: y + h*0.0), control2: CGPoint(x: x + w*0.95, y: y + h*0.05))
        // Right side: widening out
        context.addCurve(to: CGPoint(x: x + w*0.85, y: y + h*0.4), control1: CGPoint(x: x + w, y: y + h*0.2), control2: CGPoint(x: x + w*0.92, y: y + h*0.3))
        // Right lower flare
        context.addCurve(to: CGPoint(x: x + w*0.6, y: y + h*0.65), control1: CGPoint(x: x + w*0.78, y: y + h*0.5), control2: CGPoint(x: x + w*0.7, y: y + h*0.58))
        // Mid-bottom pinch
        context.addCurve(to: CGPoint(x: x + w*0.5, y: y + h*0.85), control1: CGPoint(x: x + w*0.55, y: y + h*0.72), control2: CGPoint(x: x + w*0.52, y: y + h*0.78))
        // Bottom curve
        context.addCurve(to: CGPoint(x: x + w*0.4, y: y + h), control1: CGPoint(x: x + w*0.48, y: y + h*0.95), control2: CGPoint(x: x + w*0.44, y: y + h))
        // Left side back up
        context.addCurve(to: CGPoint(x: x + w*0.15, y: y + h*0.65), control1: CGPoint(x: x + w*0.3, y: y + h), control2: CGPoint(x: x + w*0.22, y: y + h*0.8))
        context.addCurve(to: CGPoint(x: x, y: y + h*0.4), control1: CGPoint(x: x + w*0.08, y: y + h*0.55), control2: CGPoint(x: x, y: y + h*0.48))
        // Top-left section back to origin
        context.addCurve(to: CGPoint(x: x + w*0.05, y: y + h*0.15), control1: CGPoint(x: x, y: y + h*0.3), control2: CGPoint(x: x + w*0.02, y: y + h*0.22))
        context.addCurve(to: CGPoint(x: x + w*0.1, y: y + h*0.08), control1: CGPoint(x: x + w*0.06, y: y + h*0.12), control2: CGPoint(x: x + w*0.08, y: y + h*0.1))
        context.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: x + w*0.05, y: y + h*0.04), control2: CGPoint(x: x + w*0.02, y: y + h*0.02))
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
        let lower = icon.lowercased()
        if lower.contains("bomb") { return "\u{1F4A3}" }
        if lower.contains("book") { return "\u{1F4D6}" }
        if lower.contains("fire") { return "\u{1F525}" }
        if lower.contains("star") { return "\u{2B50}" }
        if lower.contains("heart") { return "\u{2764}" }
        if lower.contains("check") { return "\u{2705}" }
        if lower.contains("gear") || lower.contains("cog") { return "\u{2699}" }
        if lower.contains("user") { return "\u{1F464}" }
        if lower.contains("home") || lower.contains("house") { return "\u{1F3E0}" }
        if lower.contains("envelope") || lower.contains("mail") { return "\u{2709}" }
        if lower.contains("phone") || lower.contains("mobile") { return "\u{1F4F1}" }
        if lower.contains("calendar") { return "\u{1F4C5}" }
        if lower.contains("clock") || lower.contains("time") { return "\u{1F552}" }
        if lower.contains("map") || lower.contains("location") { return "\u{1F4CD}" }
        if lower.contains("cloud") { return "\u{2601}" }
        if lower.contains("lock") || lower.contains("key") { return "\u{1F511}" }
        if lower.contains("tag") || lower.contains("label") { return "\u{1F3F7}" }
        if lower.contains("camera") || lower.contains("photo") { return "\u{1F4F7}" }
        if lower.contains("music") || lower.contains("note") { return "\u{1F3B5}" }
        if lower.contains("film") || lower.contains("video") { return "\u{1F3AC}" }
        if lower.contains("flag") { return "\u{1F3F4}" }
        if lower.contains("wrench") || lower.contains("tool") { return "\u{1F527}" }
        if lower.contains("pencil") || lower.contains("edit") { return "\u{270F}" }
        if lower.contains("trash") || lower.contains("delete") { return "\u{1F5D1}" }
        if lower.contains("folder") { return "\u{1F4C1}" }
        if lower.contains("file") { return "\u{1F4C4}" }
        if lower.contains("globe") || lower.contains("world") { return "\u{1F310}" }
        if lower.contains("comment") || lower.contains("chat") { return "\u{1F4AC}" }
        if lower.contains("lightbulb") || lower.contains("idea") { return "\u{1F4A1}" }
        if lower.contains("rocket") { return "\u{1F680}" }
        if lower.contains("shopping") || lower.contains("cart") { return "\u{1F6D2}" }
        if lower.contains("database") { return "\u{1F5C4}" }
        if lower.contains("shield") || lower.contains("security") { return "\u{1F6E1}" }
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
#endif
