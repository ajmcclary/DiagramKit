// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import CoreGraphics

extension DiagramRenderer {

    func _drawRequirement(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .requirement(diagram) = positioned.content else { return }

        _withFittedContext(context, bounds: bounds, contentWidth: max(1, positioned.width), contentHeight: max(1, positioned.height)) { ctx in
            let ch = max(1, positioned.height)
            let config = self.config

            // Title
            if let title = diagram.diagramTitle, !title.isEmpty {
                let attr = MarkdownLabelRenderer.render(title, config: MarkdownLabelRenderer.Config(fontSize: 16, textColor: self.theme.foreground))
                let bounding = attr.boundingRect(with: CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading])
                let drawRect = CGRect(
                    x: diagram.width / 2 - bounding.width / 2,
                    y: 15 - bounding.height / 2,
                    width: bounding.width, height: bounding.height
                )
                #if os(macOS)
                attr.draw(in: drawRect)
                #else
                attr.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                #endif
            }

            // Edges
            for edge in diagram.edges {
                let pts = edge.path
                guard pts.count >= 2 else { continue }
                ctx.saveGState()
                ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
                ctx.setLineWidth(1)
                if edge.isDashed {
                    ctx.setLineDash(phase: 0, lengths: [10, 7])
                }
                ctx.move(to: pts[0])
                for i in 1..<pts.count { ctx.addLine(to: pts[i]) }
                ctx.strokePath()
                ctx.restoreGState()

                if edge.startMarker != nil {
                    _drawReqContainsStartMarker(ctx, at: pts[0], toward: pts[1])
                }
                if edge.endMarker != nil {
                    _drawReqArrowEndMarker(ctx, at: pts[pts.count - 1], toward: pts[pts.count - 2])
                }
            }

            // Edge labels
            for edge in diagram.edges {
                guard let lp = edge.labelPosition, !edge.labelText.isEmpty else { continue }
                let textW = config.estimateTextWidth(edge.labelText, fontSize: config.fontSizeEdgeLabel, fontWeight: 400) + 8
                let textH = config.fontSizeEdgeLabel + 6
                let bgRect = CGRect(x: lp.x - textW / 2, y: lp.y - textH / 2, width: textW, height: textH)
                let bgPath = BMBezierPath(roundedRect: bgRect, cornerRadius: 2)
                ctx.setFillColor(self.theme.background.cgColor)
                ctx.addPath(bgPath.bm_cgPath)
                ctx.fillPath()
                ctx.setStrokeColor(self.theme.effectiveInnerStroke().cgColor)
                ctx.setLineWidth(0.5)
                ctx.addPath(bgPath.bm_cgPath)
                ctx.strokePath()
                let attr = MarkdownLabelRenderer.render(edge.labelText, config: MarkdownLabelRenderer.Config(fontSize: config.fontSizeEdgeLabel, textColor: self.theme.effectiveMuted()))
                let bnds = attr.boundingRect(with: CGSize(width: 500, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading])
                let dr = CGRect(x: lp.x - bnds.width / 2, y: lp.y - bnds.height / 2, width: bnds.width, height: bnds.height)
                #if os(macOS)
                attr.draw(in: dr)
                #else
                attr.draw(with: dr, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                #endif
            }

            // Nodes
            for node in diagram.nodes {
                let box = CGRect(x: node.x, y: node.y, width: node.width, height: node.height)
                ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                ctx.fill(box)
                ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                ctx.setLineWidth(1)
                ctx.stroke(box)

                // Stereotype
                let stereotypeText: String
                if node.isRequirement {
                    stereotypeText = "<<\(node.requirementType?.rawValue ?? "Requirement")>>"
                } else {
                    stereotypeText = "<<Element>>"
                }
                let stereotypeY = node.y + 14
                let smallFont = BMFont.systemFont(ofSize: 11, weight: .regular)
                self._drawTextInFlipped(stereotypeText, at: CGPoint(x: node.x + node.width / 2, y: stereotypeY), context: ctx, contentHeight: ch, color: self.theme.effectiveMuted(), font: smallFont, alignment: .center)

                // Name — markdown rendered as attributed string
                let nameY = stereotypeY + 20
                let nameAttr = MarkdownLabelRenderer.render(node.id, config: MarkdownLabelRenderer.Config(fontSize: 13, textColor: self.theme.foreground))
                // Apply bold overlay to name text (requirement box convention)
                let mutable = NSMutableAttributedString(attributedString: nameAttr)
                mutable.enumerateAttributes(in: NSRange(location: 0, length: mutable.length), options: []) { attrs, range, _ in
                    var newAttrs = attrs
                    if let existingFont = attrs[.font] as? BMFont {
                        let boldFont = BMFont.boldSystemFont(ofSize: existingFont.pointSize)
                        newAttrs[.font] = boldFont
                    }
                    mutable.setAttributes(newAttrs, range: range)
                }
                let nameBounds = mutable.boundingRect(with: CGSize(width: node.width - 10, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading])
                let nameRect = CGRect(
                    x: node.x + node.width / 2 - nameBounds.width / 2,
                    y: nameY - nameBounds.height / 2,
                    width: nameBounds.width, height: nameBounds.height
                )
                #if os(macOS)
                mutable.draw(in: nameRect)
                #else
                mutable.draw(with: nameRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                #endif

                // Body
                let bodyLines = _reqBodyLines(node)
                if !bodyLines.isEmpty {
                    let dividerY = nameY + 12
                    ctx.setStrokeColor(self.theme.effectiveInnerStroke().cgColor)
                    ctx.setLineWidth(1)
                    ctx.move(to: CGPoint(x: node.x + 4, y: dividerY))
                    ctx.addLine(to: CGPoint(x: node.x + node.width - 4, y: dividerY))
                    ctx.strokePath()

                    let bodyStartY = dividerY + 16
                    for (idx, line) in bodyLines.enumerated() {
                        let rowY = bodyStartY + Double(idx) * 18
                        let bodyAttr = MarkdownLabelRenderer.render(line, config: MarkdownLabelRenderer.Config(fontSize: 11, textColor: self.theme.effectiveTextSecondary()))
                        let bnds = bodyAttr.boundingRect(with: CGSize(width: node.width - 10, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading])
                        let dr = CGRect(
                            x: node.x + node.width / 2 - bnds.width / 2,
                            y: rowY - bnds.height / 2,
                            width: bnds.width, height: bnds.height
                        )
                        #if os(macOS)
                        bodyAttr.draw(in: dr)
                        #else
                        bodyAttr.draw(with: dr, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                        #endif
                    }
                }
            }
        }
    }

    private func _drawReqContainsStartMarker(_ ctx: CGContext, at point: CGPoint, toward: CGPoint) {
        ctx.saveGState()
        ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
        ctx.setLineWidth(1)
        let dx = point.x - toward.x
        let dy = point.y - toward.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { ctx.restoreGState(); return }
        let ux = dx / len
        let uy = dy / len
        let cx = point.x + ux * 9
        let cy = point.y + uy * 9
        let r: CGFloat = 9
        let px = -uy
        let py = ux
        // Circle
        ctx.strokeEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        // Cross horizontal
        ctx.move(to: CGPoint(x: cx + px * (-r), y: cy + py * (-r)))
        ctx.addLine(to: CGPoint(x: cx + px * r, y: cy + py * r))
        ctx.strokePath()
        // Cross vertical
        ctx.move(to: CGPoint(x: cx + ux * (-r), y: cy + uy * (-r)))
        ctx.addLine(to: CGPoint(x: cx + ux * r, y: cy + uy * r))
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func _drawReqArrowEndMarker(_ ctx: CGContext, at point: CGPoint, toward: CGPoint) {
        ctx.saveGState()
        ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
        ctx.setLineWidth(1)
        let dx = point.x - toward.x
        let dy = point.y - toward.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { ctx.restoreGState(); return }
        let ux = dx / len
        let uy = dy / len
        let px = -uy
        let py = ux
        let wing: CGFloat = 10
        let backX = point.x - ux * 20
        let backY = point.y - uy * 20
        let leftX = backX - px * wing
        let leftY = backY - py * wing
        let rightX = backX + px * wing
        let rightY = backY + py * wing
        ctx.move(to: CGPoint(x: point.x, y: point.y))
        ctx.addLine(to: CGPoint(x: leftX, y: leftY))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: point.x, y: point.y))
        ctx.addLine(to: CGPoint(x: rightX, y: rightY))
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func _reqBodyLines(_ node: PositionedRequirementNode) -> [String] {
        var lines: [String] = []
        if node.isRequirement {
            if let rid = node.requirementId, !rid.isEmpty { lines.append("ID: \(rid)") }
            if let t = node.text, !t.isEmpty { lines.append("Text: \(t)") }
            if let r = node.risk { lines.append("Risk: \(r.rawValue)") }
            if let v = node.verifyMethod { lines.append("Verification: \(v.rawValue)") }
        } else {
            if let et = node.elementType, !et.isEmpty { lines.append("Type: \(et)") }
            if let dr = node.docRef, !dr.isEmpty { lines.append("Doc Ref: \(dr)") }
        }
        return lines
    }
}
#endif
