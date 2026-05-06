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

    func _drawGitGraph(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .gitGraph(pg) = positioned.content else { return }

        context.saveGState()
        defer { context.restoreGState() }

        let contentWidth = pg.width
        let contentHeight = pg.height

        _withFittedContext(context, bounds: bounds, contentWidth: max(1, contentWidth), contentHeight: max(1, contentHeight)) { ctx in

            // Title
            if let title = pg.title {
                ctx.saveGState()
                _drawTextInFlipped(
                    title.text,
                    at: CGPoint(x: title.x, y: title.y),
                    context: ctx,
                    contentHeight: contentHeight,
                    color: .darkGray,
                    font: _monoFont(size: 18),
                    alignment: .center
                )
                ctx.restoreGState()
            }

            // Branch lines
            if pg.config.showBranches {
                for bl in pg.branchLines {
                    ctx.saveGState()
                    ctx.setStrokeColor(CGColor(gray: 0.6, alpha: 1))
                    ctx.setLineWidth(1)
                    ctx.setLineDash(phase: 0, lengths: [4, 2])
                    ctx.move(to: CGPoint(x: bl.x1, y: bl.y1))
                    ctx.addLine(to: CGPoint(x: bl.x2, y: bl.y2))
                    ctx.strokePath()
                    ctx.restoreGState()
                }
            }

            // Branch labels
            for bl in pg.branchLabels {
                ctx.saveGState()
                let rect = CGRect(x: bl.x + bl.bkgX, y: bl.y + bl.bkgY, width: bl.bkgWidth, height: bl.bkgHeight)
                let roundedPath = CGPath(roundedRect: rect, cornerWidth: bl.borderRadius, cornerHeight: bl.borderRadius, transform: nil)
                ctx.setFillColor(CGColor(gray: 0.95, alpha: 1))
                ctx.addPath(roundedPath)
                ctx.fillPath()
                ctx.setStrokeColor(CGColor(gray: 0.7, alpha: 1))
                ctx.addPath(roundedPath)
                ctx.strokePath()

                _drawTextInFlipped(
                    bl.text,
                    at: CGPoint(x: bl.x, y: bl.y),
                    context: ctx,
                    contentHeight: contentHeight,
                    color: .darkGray,
                    font: _monoFont(size: 12),
                    alignment: .center
                )
                ctx.restoreGState()
            }

            // Commit bullets
            for commit in pg.commits {
                ctx.saveGState()
                let cx = commit.x
                let cy = commit.y
                let effectiveType = commit.customType ?? commit.type

                switch effectiveType {
                case .highlight:
                    let outerRect = CGRect(x: cx - 10, y: cy - 10, width: 20, height: 20)
                    ctx.setFillColor(CGColor(gray: 0.3, alpha: 1))
                    ctx.fill(outerRect)
                    let innerRect = CGRect(x: cx - 6, y: cy - 6, width: 12, height: 12)
                    ctx.setFillColor(CGColor(gray: 0.7, alpha: 1))
                    ctx.fill(innerRect)

                case .cherryPick:
                    ctx.setFillColor(CGColor(gray: 0.3, alpha: 1))
                    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: 10, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    ctx.fillPath()
                    ctx.setFillColor(.white)
                    ctx.addArc(center: CGPoint(x: cx - 3, y: cy + 2), radius: 3, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    ctx.fillPath()
                    ctx.addArc(center: CGPoint(x: cx + 3, y: cy + 2), radius: 3, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    ctx.fillPath()
                    ctx.setStrokeColor(.white)
                    ctx.setLineWidth(1.5)
                    ctx.move(to: CGPoint(x: cx + 3, y: cy + 1))
                    ctx.addLine(to: CGPoint(x: cx, y: cy - 5))
                    ctx.strokePath()
                    ctx.move(to: CGPoint(x: cx - 3, y: cy + 1))
                    ctx.addLine(to: CGPoint(x: cx, y: cy - 5))
                    ctx.strokePath()

                case .merge:
                    ctx.setFillColor(CGColor(gray: 0.3, alpha: 1))
                    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: 10, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    ctx.fillPath()
                    ctx.setFillColor(.white)
                    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: 6, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    ctx.fillPath()

                case .reverse:
                    ctx.setStrokeColor(CGColor(gray: 0.3, alpha: 1))
                    ctx.setLineWidth(2)
                    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: 10, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    ctx.strokePath()
                    ctx.move(to: CGPoint(x: cx - 4, y: cy - 4))
                    ctx.addLine(to: CGPoint(x: cx + 4, y: cy + 4))
                    ctx.strokePath()
                    ctx.move(to: CGPoint(x: cx + 4, y: cy - 4))
                    ctx.addLine(to: CGPoint(x: cx - 4, y: cy + 4))
                    ctx.strokePath()

                default:
                    ctx.setFillColor(CGColor(gray: 0.3, alpha: 1))
                    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: 10, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    ctx.fillPath()
                }

                ctx.restoreGState()
            }

            // Commit labels
            if pg.config.showCommitLabel {
                for commit in pg.commits where commit.showLabel {
                    ctx.saveGState()
                    let labelText = commit.id
                    let lx = commit.x - Double(labelText.count) * 4
                    let ly = commit.y + 20
                    let bgRect = CGRect(x: lx - 4, y: ly - 4, width: Double(labelText.count) * 8 + 8, height: 18)
                    ctx.setFillColor(CGColor(gray: 0.95, alpha: 1))
                    ctx.fill(bgRect)
                    _drawTextInFlipped(
                        labelText,
                        at: CGPoint(x: lx + 4, y: ly + 10),
                        context: ctx,
                        contentHeight: contentHeight,
                        color: .darkGray,
                        font: _monoFont(size: 10),
                        alignment: .left
                    )
                    ctx.restoreGState()
                }
            }

            // Commit tags
            for commit in pg.commits where !commit.tags.isEmpty {
                ctx.saveGState()
                var tagOffsetY = commit.y + 36
                for tag in commit.tags {
                    let tagX = commit.x - Double(tag.count) * 3

                    let tagPath = CGMutablePath()
                    tagPath.move(to: CGPoint(x: tagX, y: tagOffsetY))
                    tagPath.addLine(to: CGPoint(x: tagX + 8, y: tagOffsetY))
                    tagPath.addLine(to: CGPoint(x: tagX + 10, y: tagOffsetY - 4))
                    tagPath.addLine(to: CGPoint(x: tagX + 18 + Double(tag.count) * 6, y: tagOffsetY - 4))
                    tagPath.addLine(to: CGPoint(x: tagX + 18 + Double(tag.count) * 6, y: tagOffsetY + 4))
                    tagPath.addLine(to: CGPoint(x: tagX + 10, y: tagOffsetY + 4))
                    tagPath.addLine(to: CGPoint(x: tagX + 8, y: tagOffsetY))
                    ctx.setFillColor(CGColor(gray: 0.9, alpha: 1))
                    ctx.addPath(tagPath)
                    ctx.fillPath()
                    ctx.setStrokeColor(CGColor(gray: 0.6, alpha: 1))
                    ctx.setLineWidth(0.5)
                    ctx.addPath(tagPath)
                    ctx.strokePath()

                    _drawTextInFlipped(
                        tag,
                        at: CGPoint(x: tagX + 10, y: tagOffsetY),
                        context: ctx,
                        contentHeight: contentHeight,
                        color: .darkGray,
                        font: _monoFont(size: 8),
                        alignment: .left
                    )
                    tagOffsetY += 14
                }
                ctx.restoreGState()
            }

            // Arrows
            for arrow in pg.arrows {
                ctx.saveGState()
                ctx.setStrokeColor(CGColor(gray: 0.4, alpha: 1))
                ctx.setLineWidth(1.5)
                var first = true
                for segment in arrow.segments {
                    switch segment {
                    case .line(let from, let to):
                        if first { ctx.move(to: CGPoint(x: from.x, y: from.y)); first = false }
                        ctx.addLine(to: CGPoint(x: to.x, y: to.y))
                    case .cubic(let from, let c1, let c2, let to):
                        if first { ctx.move(to: CGPoint(x: from.x, y: from.y)); first = false }
                        ctx.addCurve(to: CGPoint(x: to.x, y: to.y), control1: CGPoint(x: c1.x, y: c1.y), control2: CGPoint(x: c2.x, y: c2.y))
                    case .arc(let from, let to, _, _, _, _, _):
                        if first { ctx.move(to: CGPoint(x: from.x, y: from.y)); first = false }
                        ctx.addLine(to: CGPoint(x: to.x, y: to.y))
                    }
                }
                ctx.strokePath()

                if let lastSegment = arrow.segments.last {
                    let endPoint: GitGraphPoint
                    switch lastSegment {
                    case .line(_, let to), .arc(_, let to, _, _, _, _, _):
                        endPoint = to
                    case .cubic(_, _, _, let to):
                        endPoint = to
                    }
                    ctx.move(to: CGPoint(x: endPoint.x, y: endPoint.y))
                    ctx.addLine(to: CGPoint(x: endPoint.x - 6, y: endPoint.y - 3))
                    ctx.move(to: CGPoint(x: endPoint.x, y: endPoint.y))
                    ctx.addLine(to: CGPoint(x: endPoint.x - 6, y: endPoint.y + 3))
                    ctx.strokePath()
                }
                ctx.restoreGState()
            }
        }
    }
}
