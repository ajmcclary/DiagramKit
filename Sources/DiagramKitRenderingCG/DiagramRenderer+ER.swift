// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import CoreGraphics

extension DiagramRenderer {

    func _drawEr(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard
            let entities = positioned.erEntities,
            let relationships = positioned.erRelationships,
            !entities.isEmpty
        else { return }

        _withFittedContext(context, bounds: bounds, contentWidth: max(1, positioned.width), contentHeight: max(1, positioned.height)) { ctx in
            let ch = max(1, positioned.height)

            let config = self.config

            // Relationship lines
            for rel in relationships {
                let pts = rel.points.map { CGPoint(x: $0.x, y: $0.y) }
                guard pts.count >= 2 else { continue }
                ctx.saveGState()
                ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
                ctx.setLineWidth(config.strokeWidthConnector)
                if !rel.identifying { ctx.setLineDash(phase: 0, lengths: [6, 4]) }
                ctx.move(to: pts[0])
                for i in 1..<pts.count { ctx.addLine(to: pts[i]) }
                ctx.strokePath()
                ctx.restoreGState()
            }

            // Entity boxes
            for entity in entities {
                let box = CGRect(x: entity.x, y: entity.y, width: entity.width, height: entity.height)

                // Check for per-entity fill/stroke from cssStyles
                let effectiveStyles = entity.cssCompiledStyles + entity.cssStyles
                let entityFill = _extractCGStyleValue(effectiveStyles, property: "fill")
                let entityStroke = _extractCGStyleValue(effectiveStyles, property: "stroke")
                let entityText = _extractCGStyleValue(effectiveStyles, property: "color")

                if let f = entityFill {
                    ctx.setFillColor(f)
                } else {
                    ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                }
                ctx.fill(box)

                if let s = entityStroke {
                    ctx.setStrokeColor(s)
                } else {
                    ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                }
                ctx.setLineWidth(config.strokeWidthOuterBox)
                ctx.stroke(box)

                let headerRect = CGRect(x: entity.x, y: entity.y, width: entity.width, height: entity.headerHeight)
                ctx.setFillColor(self.theme.subgraphHeaderColor().cgColor)
                ctx.fill(headerRect)
                if let s = entityStroke {
                    ctx.setStrokeColor(s)
                } else {
                    ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                }
                ctx.stroke(headerRect)

                // Use alias label if present
                let displayLabel = entity.alias.isEmpty ? entity.label : entity.alias
                let nameFont = self.fontResolver.proportionalFont(size: config.fontSizeNodeLabel, weight: .bold)
                self._drawTextInFlipped(
                    displayLabel,
                    at: CGPoint(x: entity.x + entity.width / 2, y: entity.y + entity.headerHeight / 2),
                    context: ctx, contentHeight: ch,
                    color: entityText.map { BMColor(cgColor: $0) ?? self.theme.foreground } ?? self.theme.foreground,
                    font: nameFont,
                    alignment: .center
                )

                if entity.attributes.isEmpty {
                    // Simple rectangle — no attribute section, no "(no attributes)" text
                    continue
                }

                let attrTop = entity.y + entity.headerHeight
                if let s = entityStroke {
                    ctx.setStrokeColor(s)
                } else {
                    ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                }
                ctx.setLineWidth(config.strokeWidthInnerBox)
                ctx.move(to: CGPoint(x: entity.x, y: attrTop))
                ctx.addLine(to: CGPoint(x: entity.x + entity.width, y: attrTop))
                ctx.strokePath()

                let monoFont = self._monoFont(size: config.erAttrFontSize)

                // Compute max key width for column alignment
                var maxKeyW: CGFloat = 0
                for attr in entity.attributes where !attr.keys.isEmpty {
                    let kt = attr.keys.joined(separator: ",")
                    let w = config.estimateTextWidth(kt, fontSize: 9, fontWeight: 600) + 8
                    maxKeyW = max(maxKeyW, w)
                }

                // Compute comment column position
                var maxCommentW: CGFloat = 0
                for attr in entity.attributes where !attr.comment.isEmpty {
                    let w = config.estimateTextWidth(attr.comment, fontSize: 9, fontWeight: 400)
                    maxCommentW = max(maxCommentW, w + 12)
                }

                let keyColRight = maxKeyW > 0 ? entity.x + 6 + maxKeyW + 14 : -1
                let commentColLeft = maxCommentW > 0 ? entity.width - maxCommentW - 8 : -1

                // Vertical column dividers
                if keyColRight > 0 {
                    ctx.setStrokeColor(self.theme.effectiveInnerStroke().cgColor)
                    ctx.setLineWidth(0.5)
                    ctx.move(to: CGPoint(x: keyColRight, y: attrTop))
                    ctx.addLine(to: CGPoint(x: keyColRight, y: entity.y + entity.height))
                    ctx.strokePath()
                }
                if commentColLeft > 0 {
                    let dividerX = entity.x + commentColLeft
                    ctx.setStrokeColor(self.theme.effectiveInnerStroke().cgColor)
                    ctx.setLineWidth(0.5)
                    ctx.move(to: CGPoint(x: dividerX, y: attrTop))
                    ctx.addLine(to: CGPoint(x: dividerX, y: entity.y + entity.height))
                    ctx.strokePath()
                }

                for i in 0..<entity.attributes.count {
                    let attr = entity.attributes[i]
                    let rowY = attrTop + CGFloat(i) * entity.rowHeight + entity.rowHeight / 2

                    // Row striping background
                    if i % 2 == 1 {
                        ctx.setFillColor(self.theme.effectiveSurface().cgColor.copy(alpha: 0.15) ?? self.theme.effectiveSurface().cgColor)
                        ctx.fill(CGRect(x: entity.x, y: attrTop + CGFloat(i) * entity.rowHeight, width: entity.width, height: entity.rowHeight))
                    }

                    // Key badges
                    if !attr.keys.isEmpty {
                        let keyText = attr.keys.joined(separator: ",")
                        let keyWidth = config.estimateTextWidth(keyText, fontSize: 9, fontWeight: 600) + 8
                        let badgeRect = CGRect(x: entity.x + 6, y: rowY - 7, width: keyWidth, height: 14)
                        let badgePath = BMBezierPath(roundedRect: badgeRect, cornerRadius: 2)
                        ctx.setFillColor(self.theme.keyBadgeColor().cgColor)
                        ctx.addPath(badgePath.bm_cgPath)
                        ctx.fillPath()

                        let keyFont = self.fontResolver.proportionalFont(size: 9, weight: .semibold)
                        self._drawTextInFlipped(keyText, at: CGPoint(x: entity.x + 6 + keyWidth / 2, y: rowY), context: ctx, contentHeight: ch, color: self.theme.effectiveTextSecondary(), font: keyFont, alignment: .center)
                    }

                    // Type (left, after key column)
                    let typeX = keyColRight > 0 ? keyColRight + 6 : entity.x + 8
                    self._drawTextInFlipped(attr.type, at: CGPoint(x: typeX, y: rowY), context: ctx, contentHeight: ch, color: self.theme.effectiveMuted(), font: monoFont, alignment: .left)

                    // Name — positioned before comment column if present
                    let nameEndX = commentColLeft > 0 ? entity.x + commentColLeft - 8 : entity.x + entity.width - 8
                    self._drawTextInFlipped(attr.name, at: CGPoint(x: nameEndX, y: rowY), context: ctx, contentHeight: ch, color: self.theme.effectiveTextSecondary(), font: monoFont, alignment: .right)

                    // Comment column
                    if !attr.comment.isEmpty, commentColLeft > 0 {
                        let commentX = entity.x + commentColLeft + 4
                        let commentFont = self._monoFont(size: 9)
                        self._drawTextInFlipped(attr.comment, at: CGPoint(x: commentX, y: rowY), context: ctx, contentHeight: ch, color: self.theme.effectiveTextFaint(), font: commentFont, alignment: .left)
                    }
                }
            }

            // Cardinality markers
            for rel in relationships {
                let pts = rel.points.map { CGPoint(x: $0.x, y: $0.y) }
                guard pts.count >= 2 else { continue }
                self._drawCrowsFoot(point: pts[0], toward: pts[1], cardinality: rel.cardinality1, in: ctx)
                self._drawCrowsFoot(point: pts[pts.count - 1], toward: pts[pts.count - 2], cardinality: rel.cardinality2, in: ctx)
            }

            // Relationship labels with background + border
            for rel in relationships {
                guard !rel.label.isEmpty else { continue }
                let pts = rel.points.map { CGPoint(x: $0.x, y: $0.y) }
                let mid = self._arcLengthMidpoint(pts)
                let labelFont = config.edgeLabelFont()
                let textW = config.estimateTextWidth(rel.label, fontSize: config.fontSizeEdgeLabel, fontWeight: 400) + 8
                let textH = config.fontSizeEdgeLabel + 6
                let bgRect = CGRect(x: mid.x - textW / 2, y: mid.y - textH / 2, width: textW, height: textH)
                let bgPath = BMBezierPath(roundedRect: bgRect, cornerRadius: 2)
                ctx.setFillColor(self.theme.background.cgColor)
                ctx.addPath(bgPath.bm_cgPath)
                ctx.fillPath()
                ctx.setStrokeColor(self.theme.effectiveInnerStroke().cgColor)
                ctx.setLineWidth(0.5)
                ctx.addPath(bgPath.bm_cgPath)
                ctx.strokePath()
                self._drawTextInFlipped(rel.label, at: mid, context: ctx, contentHeight: ch, color: self.theme.effectiveMuted(), font: labelFont, alignment: .center)
            }
        }
    }

    private func _extractCGStyleValue(_ styles: [String], property: String) -> CGColor? {
        for style in styles.reversed() {
            let parts = style.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0] == property {
                return _parseCGColor(String(parts[1]))
            }
        }
        return nil
    }

    private func _parseCGColor(_ hex: String) -> CGColor? {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if hex.count == 6 {
            var rgb: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&rgb)
            return CGColor(red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
                           green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
                           blue: CGFloat(rgb & 0xFF) / 255.0,
                           alpha: 1.0)
        }
        return nil
    }

    private func _drawCrowsFoot(point: CGPoint, toward: CGPoint, cardinality: String, in context: CGContext) {
        let sw = self.config.strokeWidthConnector + 0.25
        let dx = point.x - toward.x, dy = point.y - toward.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { return }
        let ux = dx / len, uy = dy / len
        let px = -uy, py = ux

        let tipX = point.x - ux * 4, tipY = point.y - uy * 4

        let upper = cardinality.uppercased()
        let hasOneLine = upper == "ONLY_ONE" || upper == "ZERO_OR_ONE" || upper == "ONE" || upper == "ZERO-ONE"
        let hasCrowsFoot = upper == "ONE_OR_MORE" || upper == "ZERO_OR_MORE" || upper == "MANY" || upper == "ZERO-MANY"
        let hasCircle = upper == "ZERO_OR_ONE" || upper == "ZERO_OR_MORE" || upper == "ZERO-ONE" || upper == "ZERO-MANY"
        let isParent = upper == "MD_PARENT"

        context.saveGState()
        context.setStrokeColor(theme.effectiveLine().cgColor)
        context.setLineWidth(sw)

        if isParent {
            let diamondSize: CGFloat = 6
            let offsetX = tipX - ux * 8
            let offsetY = tipY - uy * 8
            context.move(to: CGPoint(x: offsetX, y: offsetY - diamondSize))
            context.addLine(to: CGPoint(x: offsetX + diamondSize, y: offsetY))
            context.addLine(to: CGPoint(x: offsetX, y: offsetY + diamondSize))
            context.addLine(to: CGPoint(x: offsetX - diamondSize, y: offsetY))
            context.closePath()
            context.setFillColor(theme.effectiveLine().cgColor)
            context.fillPath()
        }

        if hasOneLine {
            let halfW: CGFloat = 6
            context.move(to: CGPoint(x: tipX + px * halfW, y: tipY + py * halfW))
            context.addLine(to: CGPoint(x: tipX - px * halfW, y: tipY - py * halfW))
            context.strokePath()
            let line2X = tipX - ux * 4, line2Y = tipY - uy * 4
            context.move(to: CGPoint(x: line2X + px * halfW, y: line2Y + py * halfW))
            context.addLine(to: CGPoint(x: line2X - px * halfW, y: line2Y - py * halfW))
            context.strokePath()
        }

        if hasCrowsFoot {
            let fanW: CGFloat = 7
            let backX = point.x - ux * 16, backY = point.y - uy * 16
            context.move(to: CGPoint(x: tipX + px * fanW, y: tipY + py * fanW))
            context.addLine(to: CGPoint(x: backX, y: backY))
            context.strokePath()
            context.move(to: CGPoint(x: tipX, y: tipY))
            context.addLine(to: CGPoint(x: backX, y: backY))
            context.strokePath()
            context.move(to: CGPoint(x: tipX - px * fanW, y: tipY - py * fanW))
            context.addLine(to: CGPoint(x: backX, y: backY))
            context.strokePath()
        }

        if hasCircle {
            let circleOffset: CGFloat = hasCrowsFoot ? 20 : 12
            let cx = point.x - ux * circleOffset, cy = point.y - uy * circleOffset
            let circleRect = CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8)
            context.setFillColor(theme.background.cgColor)
            context.fillEllipse(in: circleRect)
            context.strokeEllipse(in: circleRect)
        }

        context.restoreGState()
    }

    func _arcLengthMidpoint(_ points: [CGPoint]) -> CGPoint {
        guard points.count > 1 else { return points.first ?? .zero }
        var totalLen: CGFloat = 0
        for i in 1..<points.count {
            let dx = points[i].x - points[i - 1].x, dy = points[i].y - points[i - 1].y
            totalLen += sqrt(dx * dx + dy * dy)
        }
        guard totalLen > 0 else { return points[0] }
        let halfLen = totalLen / 2
        var walked: CGFloat = 0
        for i in 1..<points.count {
            let dx = points[i].x - points[i - 1].x, dy = points[i].y - points[i - 1].y
            let segLen = sqrt(dx * dx + dy * dy)
            if walked + segLen >= halfLen {
                let t = segLen > 0 ? (halfLen - walked) / segLen : 0
                return CGPoint(x: points[i - 1].x + dx * t, y: points[i - 1].y + dy * t)
            }
            walked += segLen
        }
        guard let last = points.last else { return points[0] }
        return last
    }
}
#endif
