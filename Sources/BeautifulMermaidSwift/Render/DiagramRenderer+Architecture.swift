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
    func _drawArchitecture(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .architecture(data) = positioned.content else { return }

        if !theme.transparent {
            context.setFillColor(theme.background.cgColor)
            context.fill(bounds)
        }

        let bw = CGFloat(data.width)
        let bh = CGFloat(data.height)
        guard bw > 0, bh > 0 else { return }

        let scale = min(bounds.width / bw, bounds.height / bh)
        let ox = bounds.minX + (bounds.width - bw * scale) / 2
        let oy = bounds.minY + (bounds.height - bh * scale) / 2

        context.saveGState()
        context.translateBy(x: ox, y: oy)
        context.scaleBy(x: scale, y: scale)

        let fgColor = theme.foreground
        let themeCfg = data.theme
        let defaultTheme = ArchitectureThemeConfig.default
        let lineColor = themeCfg.map { BMColor(hex: $0.archEdgeColor) } ?? theme.effectiveLine()
        let arrowColor = themeCfg.map { BMColor(hex: $0.archEdgeArrowColor) } ?? lineColor
        let groupBorderColor = BMColor(hex: themeCfg?.archGroupBorderColor ?? defaultTheme.archGroupBorderColor)
        let edgeWidth = _architectureStrokeWidth(themeCfg?.archEdgeWidth ?? defaultTheme.archEdgeWidth, fallback: 3)
        let groupBorderWidth = _architectureStrokeWidth(themeCfg?.archGroupBorderWidth ?? defaultTheme.archGroupBorderWidth, fallback: 2)

        let iconSize = CGFloat(data.config.iconSize)
        let cgArrowSize = iconSize / 6

        if let title = data.diagramTitle, !title.isEmpty {
            let font = _monoFont(size: CGFloat(data.config.fontSize))
            _drawTextInFlipped(
                title,
                at: CGPoint(x: bw / 2, y: CGFloat(data.config.padding / 2 + data.config.fontSize)),
                context: context,
                contentHeight: bh,
                color: fgColor,
                font: font,
                alignment: .center
            )
        }

        for group in data.groups {
            let rect = CGRect(x: CGFloat(group.x), y: CGFloat(group.y), width: CGFloat(group.width), height: CGFloat(group.height))
            context.setStrokeColor(groupBorderColor.cgColor)
            context.setLineWidth(groupBorderWidth)
            context.setLineDash(phase: 0, lengths: [8, 8])
            context.addRect(rect)
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])

            if let icon = group.icon, !icon.isEmpty {
                let groupIconSize = CGFloat(data.config.padding * 0.75)
                _drawArchitectureIcon(
                    icon,
                    iconText: nil,
                    in: CGRect(x: rect.minX + 1, y: rect.minY + 1, width: groupIconSize, height: groupIconSize),
                    context: context,
                    contentHeight: bh,
                    color: fgColor
                )
            }

            if let title = group.title, !title.isEmpty {
                let font = _monoFont(size: CGFloat(data.config.fontSize))
                let labelX = rect.minX + 4 + (group.icon == nil ? 0 : CGFloat(data.config.padding * 0.75))
                _drawTextInFlipped(title, at: CGPoint(x: labelX, y: rect.minY + CGFloat(data.config.fontSize)), context: context, contentHeight: bh, color: fgColor, font: font, alignment: .left)
            }
        }

        for service in data.services {
            let rect = CGRect(
                x: CGFloat(service.x - service.width / 2),
                y: CGFloat(service.y - service.height / 2),
                width: CGFloat(service.width),
                height: CGFloat(service.height)
            )
            context.setStrokeColor(fgColor.cgColor)
            context.setLineWidth(1)
            context.addRect(rect)
            context.strokePath()

            _drawArchitectureIcon(
                service.icon,
                iconText: _sanitizeIconText(service.iconText),
                in: CGRect(
                    x: CGFloat(service.x - data.config.iconSize / 2),
                    y: CGFloat(service.y - data.config.iconSize / 2),
                    width: CGFloat(data.config.iconSize),
                    height: CGFloat(data.config.iconSize)
                ),
                context: context,
                contentHeight: bh,
                color: fgColor
            )

            if let title = service.title, !title.isEmpty {
                let font = _monoFont(size: CGFloat(data.config.fontSize))
                _drawTextInFlipped(
                    title,
                    at: CGPoint(x: CGFloat(service.x), y: rect.maxY + CGFloat(data.config.fontSize) + 2),
                    context: context,
                    contentHeight: bh,
                    color: fgColor,
                    font: font,
                    alignment: .center
                )
            }
        }

        for edge in data.edges {
            context.setStrokeColor(lineColor.cgColor)
            context.setLineWidth(edgeWidth)

            context.beginPath()
            context.move(to: CGPoint(x: CGFloat(edge.startX), y: CGFloat(edge.startY)))
            context.addLine(to: CGPoint(x: CGFloat(edge.midX), y: CGFloat(edge.midY)))
            context.addLine(to: CGPoint(x: CGFloat(edge.endX), y: CGFloat(edge.endY)))
            context.strokePath()

            if edge.sourceArrow {
                _drawDirectionArrowhead(
                    direction: edge.lhsDirection,
                    at: CGPoint(x: CGFloat(edge.startX), y: CGFloat(edge.startY)),
                    midpoint: CGPoint(x: CGFloat(edge.midX), y: CGFloat(edge.midY)),
                    size: cgArrowSize,
                    in: context,
                    fillColor: arrowColor
                )
            }
            if edge.targetArrow {
                _drawDirectionArrowhead(
                    direction: edge.rhsDirection,
                    at: CGPoint(x: CGFloat(edge.endX), y: CGFloat(edge.endY)),
                    midpoint: CGPoint(x: CGFloat(edge.midX), y: CGFloat(edge.midY)),
                    size: cgArrowSize,
                    in: context,
                    fillColor: arrowColor
                )
            }

            if let label = edge.label, !label.isEmpty {
                let font = _monoFont(size: CGFloat(data.config.fontSize))
                _drawTextInFlipped(label, at: CGPoint(x: CGFloat(edge.midX), y: CGFloat(edge.midY) - 4), context: context, contentHeight: bh, color: fgColor, font: font, alignment: .center)
            }
        }

        for junction in data.junctions {
            let rect = CGRect(
                x: CGFloat(junction.x - junction.width / 2),
                y: CGFloat(junction.y - junction.height / 2),
                width: CGFloat(junction.width),
                height: CGFloat(junction.height)
            )
            context.setFillColor(BMColor.clear.cgColor)
            context.fill(rect)
        }

        context.restoreGState()
    }

    private func _drawDirectionArrowhead(
        direction: ArchitectureDirection,
        at point: CGPoint,
        midpoint: CGPoint,
        size: CGFloat,
        in context: CGContext,
        fillColor: BMColor
    ) {
        let halfSize = size / 2
        context.beginPath()
        switch direction {
        case .L:
            let p1 = CGPoint(x: point.x, y: point.y - halfSize)
            let p2 = CGPoint(x: point.x, y: point.y + halfSize)
            let p3 = CGPoint(x: point.x - size, y: point.y)
            context.move(to: p1)
            context.addLine(to: p2)
            context.addLine(to: p3)
        case .R:
            let p1 = CGPoint(x: point.x, y: point.y - halfSize)
            let p2 = CGPoint(x: point.x, y: point.y + halfSize)
            let p3 = CGPoint(x: point.x + size, y: point.y)
            context.move(to: p1)
            context.addLine(to: p2)
            context.addLine(to: p3)
        case .T:
            let p1 = CGPoint(x: point.x - halfSize, y: point.y)
            let p2 = CGPoint(x: point.x + halfSize, y: point.y)
            let p3 = CGPoint(x: point.x, y: point.y - size)
            context.move(to: p1)
            context.addLine(to: p2)
            context.addLine(to: p3)
        case .B:
            let p1 = CGPoint(x: point.x - halfSize, y: point.y)
            let p2 = CGPoint(x: point.x + halfSize, y: point.y)
            let p3 = CGPoint(x: point.x, y: point.y + size)
            context.move(to: p1)
            context.addLine(to: p2)
            context.addLine(to: p3)
        }
        context.closePath()
        context.setFillColor(fillColor.cgColor)
        context.fillPath()
    }

    private func _drawArrowhead(at point: CGPoint, direction: CGFloat, size: CGFloat, in context: CGContext, fillColor: BMColor) {
        context.beginPath()
        context.move(to: point)
        let angle: CGFloat = .pi * 150 / 180
        let x1 = point.x + size * cos(direction + angle)
        let y1 = point.y + size * sin(direction + angle)
        let x2 = point.x + size * cos(direction - angle)
        let y2 = point.y + size * sin(direction - angle)
        context.addLine(to: CGPoint(x: x1, y: y1))
        context.addLine(to: CGPoint(x: x2, y: y2))
        context.closePath()
        context.setFillColor(fillColor.cgColor)
        context.fillPath()
    }

    private func _architectureStrokeWidth(_ value: String, fallback: CGFloat) -> CGFloat {
        let numeric = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "px", with: "")
        return CGFloat(Double(numeric) ?? Double(fallback))
    }

    private func _drawArchitectureIcon(
        _ icon: String?,
        iconText: String?,
        in rect: CGRect,
        context: CGContext,
        contentHeight: CGFloat,
        color: BMColor
    ) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(max(1.5, rect.width / 36))

        if let iconText, !iconText.isEmpty {
            let font = _monoFont(size: max(8, rect.width * 0.22))
            _drawTextInFlipped(
                iconText,
                at: CGPoint(x: rect.midX, y: rect.midY + font.pointSize / 3),
                context: context,
                contentHeight: contentHeight,
                color: color,
                font: font,
                alignment: .center
            )
            context.restoreGState()
            return
        }

        switch icon?.lowercased().trimmingCharacters(in: .whitespaces) {
        case "cloud":
            _drawCloudIcon(in: rect, context: context)
        case "database":
            _drawDatabaseIcon(in: rect, context: context)
        case "disk":
            _drawDiskIcon(in: rect, context: context)
        case "internet":
            _drawInternetIcon(in: rect, context: context)
        case "server":
            _drawServerIcon(in: rect, context: context)
        case "logos:aws-s3":
            _drawS3Icon(in: rect, context: context)
        case .some:
            _drawUnknownIcon(in: rect, context: context, contentHeight: contentHeight, color: color)
        case .none:
            break
        }

        context.restoreGState()
    }

    private func _drawCloudIcon(in rect: CGRect, context: CGContext) {
        let r = rect.insetBy(dx: rect.width * 0.16, dy: rect.height * 0.24)
        context.addEllipse(in: CGRect(x: r.minX, y: r.midY - r.height * 0.25, width: r.width * 0.42, height: r.height * 0.5))
        context.addEllipse(in: CGRect(x: r.minX + r.width * 0.25, y: r.minY, width: r.width * 0.45, height: r.height * 0.72))
        context.addEllipse(in: CGRect(x: r.minX + r.width * 0.55, y: r.midY - r.height * 0.3, width: r.width * 0.42, height: r.height * 0.56))
        context.strokePath()
    }

    private func _drawDatabaseIcon(in rect: CGRect, context: CGContext) {
        let r = rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.18)
        let top = CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height * 0.28)
        context.addEllipse(in: top)
        context.move(to: CGPoint(x: r.minX, y: top.midY))
        context.addLine(to: CGPoint(x: r.minX, y: r.maxY - top.height / 2))
        context.move(to: CGPoint(x: r.maxX, y: top.midY))
        context.addLine(to: CGPoint(x: r.maxX, y: r.maxY - top.height / 2))
        context.addEllipse(in: CGRect(x: r.minX, y: r.maxY - top.height, width: r.width, height: top.height))
        context.move(to: CGPoint(x: r.minX, y: r.midY))
        context.addCurve(
            to: CGPoint(x: r.maxX, y: r.midY),
            control1: CGPoint(x: r.minX + r.width * 0.25, y: r.midY + top.height / 2),
            control2: CGPoint(x: r.maxX - r.width * 0.25, y: r.midY + top.height / 2)
        )
        context.strokePath()
    }

    private func _drawDiskIcon(in rect: CGRect, context: CGContext) {
        let r = rect.insetBy(dx: rect.width * 0.2, dy: rect.height * 0.18)
        context.addRect(r)
        context.addRect(CGRect(x: r.minX + r.width * 0.18, y: r.minY + r.height * 0.12, width: r.width * 0.44, height: r.height * 0.2))
        context.addEllipse(in: CGRect(x: r.midX - r.width * 0.16, y: r.midY, width: r.width * 0.32, height: r.width * 0.32))
        context.strokePath()
    }

    private func _drawInternetIcon(in rect: CGRect, context: CGContext) {
        let r = rect.insetBy(dx: rect.width * 0.16, dy: rect.height * 0.16)
        context.addEllipse(in: r)
        context.move(to: CGPoint(x: r.midX, y: r.minY))
        context.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        context.move(to: CGPoint(x: r.minX, y: r.midY))
        context.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        context.addEllipse(in: r.insetBy(dx: r.width * 0.28, dy: 0))
        context.strokePath()
    }

    private func _drawServerIcon(in rect: CGRect, context: CGContext) {
        let r = rect.insetBy(dx: rect.width * 0.16, dy: rect.height * 0.18)
        let shelfHeight = r.height / 3.5
        for index in 0..<3 {
            let y = r.minY + CGFloat(index) * (shelfHeight + r.height * 0.08)
            let shelf = CGRect(x: r.minX, y: y, width: r.width, height: shelfHeight)
            context.addRect(shelf)
            context.move(to: CGPoint(x: shelf.minX + shelf.width * 0.12, y: shelf.midY))
            context.addLine(to: CGPoint(x: shelf.minX + shelf.width * 0.22, y: shelf.midY))
        }
        context.strokePath()
    }

    private func _drawS3Icon(in rect: CGRect, context: CGContext) {
        let r = rect.insetBy(dx: rect.width * 0.2, dy: rect.height * 0.14)
        let top = CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height * 0.22)
        context.addEllipse(in: top)
        context.move(to: CGPoint(x: r.minX, y: top.midY))
        context.addLine(to: CGPoint(x: r.minX, y: r.maxY - top.height / 2))
        context.move(to: CGPoint(x: r.maxX, y: top.midY))
        context.addLine(to: CGPoint(x: r.maxX, y: r.maxY - top.height / 2))
        context.addEllipse(in: CGRect(x: r.minX, y: r.maxY - top.height, width: r.width, height: top.height))
        for factor in [0.42, 0.64] {
            let y = r.minY + r.height * factor
            context.move(to: CGPoint(x: r.minX, y: y))
            context.addCurve(
                to: CGPoint(x: r.maxX, y: y),
                control1: CGPoint(x: r.minX + r.width * 0.25, y: y + top.height / 2),
                control2: CGPoint(x: r.maxX - r.width * 0.25, y: y + top.height / 2)
            )
        }

        let cube = CGRect(x: r.midX - r.width * 0.18, y: r.minY - r.height * 0.05, width: r.width * 0.36, height: r.height * 0.18)
        context.addRect(cube)
        context.strokePath()
    }

    private func _drawUnknownIcon(in rect: CGRect, context: CGContext, contentHeight: CGFloat, color: BMColor) {
        let r = rect.insetBy(dx: rect.width * 0.18, dy: rect.height * 0.18)
        context.addEllipse(in: r)
        context.strokePath()
        _drawTextInFlipped(
            "?",
            at: CGPoint(x: r.midX, y: r.midY + rect.height * 0.08),
            context: context,
            contentHeight: contentHeight,
            color: color,
            font: _monoFont(size: max(10, rect.width * 0.34)),
            alignment: .center
        )
    }
}
