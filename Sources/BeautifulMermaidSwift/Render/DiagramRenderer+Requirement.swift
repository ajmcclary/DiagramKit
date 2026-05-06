import Foundation
import CoreGraphics

extension DiagramRenderer {

    func _drawRequirement(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .requirement(diagram) = positioned.content else { return }

        _withFittedContext(context, bounds: bounds, contentWidth: max(1, positioned.width), contentHeight: max(1, positioned.height)) { ctx in
            let ch = max(1, positioned.height)
            let config = self.config

            // Title
            if let title = diagram.diagramTitle, !title.isEmpty {
                self._drawTextInFlipped(title, at: CGPoint(x: diagram.width / 2, y: 15), context: ctx, contentHeight: ch, color: self.theme.foreground, font: BMFont.systemFont(ofSize: 16, weight: .bold), alignment: .center)
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

                // Markers
                if edge.startMarker == "requirement_contains" {
                    _drawReqContainsStartMarker(ctx, at: pts[0], toward: pts[1])
                }
                if edge.endMarker == "requirement_arrow" {
                    _drawReqArrowEndMarker(ctx, at: pts[pts.count - 1], toward: pts[pts.count - 2])
                }
            }

            // Edge labels
            for edge in diagram.edges {
                guard let lp = edge.labelPosition, !edge.labelText.isEmpty else { continue }
                let labelFont = BMFont.systemFont(ofSize: config.fontSizeEdgeLabel)
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
                self._drawTextInFlipped(edge.labelText, at: lp, context: ctx, contentHeight: ch, color: self.theme.effectiveMuted(), font: labelFont, alignment: .center)
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

                // Name
                let nameY = stereotypeY + 20
                let nameFont = BMFont.systemFont(ofSize: 13, weight: .bold)
                self._drawTextInFlipped(node.id, at: CGPoint(x: node.x + node.width / 2, y: nameY), context: ctx, contentHeight: ch, color: self.theme.foreground, font: nameFont, alignment: .center)

                // Body
                let bodyLines = _reqBodyLines(node)
                if !bodyLines.isEmpty {
                    let dividerY = nameY + 12
                    ctx.setStrokeColor(self.theme.effectiveInnerStroke().cgColor)
                    ctx.setLineWidth(1)
                    ctx.move(to: CGPoint(x: node.x + 4, y: dividerY))
                    ctx.addLine(to: CGPoint(x: node.x + node.width - 4, y: dividerY))
                    ctx.strokePath()

                    let bodyFont = BMFont.systemFont(ofSize: 11, weight: .regular)
                    let bodyStartY = dividerY + 16
                    for (idx, line) in bodyLines.enumerated() {
                        let rowY = bodyStartY + Double(idx) * 18
                        let textColor = idx == 0 ? self.theme.effectiveTextSecondary() : self.theme.effectiveTextSecondary()
                        self._drawTextInFlipped(line, at: CGPoint(x: node.x + node.width / 2, y: rowY), context: ctx, contentHeight: ch, color: textColor, font: bodyFont, alignment: .center)
                    }
                }
            }
        }
    }

    private func _drawReqContainsStartMarker(_ ctx: CGContext, at point: CGPoint, toward: CGPoint) {
        ctx.saveGState()
        ctx.setFillColor(self.theme.effectiveLine().cgColor)
        let dx = point.x - toward.x
        let dy = point.y - toward.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { ctx.restoreGState(); return }
        let ux = dx / len
        let uy = dy / len
        let cx = point.x + ux * 3
        let cy = point.y + uy * 3
        let r: CGFloat = 3
        ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ctx.restoreGState()
    }

    private func _drawReqArrowEndMarker(_ ctx: CGContext, at point: CGPoint, toward: CGPoint) {
        ctx.saveGState()
        ctx.setFillColor(self.theme.effectiveLine().cgColor)
        let dx = point.x - toward.x
        let dy = point.y - toward.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0 else { ctx.restoreGState(); return }
        let ux = dx / len
        let uy = dy / len
        let px = -uy
        let py = ux
        let tipX = point.x
        let tipY = point.y
        let backX = point.x - ux * 10
        let backY = point.y - uy * 10
        let wing: CGFloat = 5
        ctx.move(to: CGPoint(x: tipX, y: tipY))
        ctx.addLine(to: CGPoint(x: backX + px * wing, y: backY + py * wing))
        ctx.addLine(to: CGPoint(x: backX - px * wing, y: backY - py * wing))
        ctx.closePath()
        ctx.fillPath()
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
