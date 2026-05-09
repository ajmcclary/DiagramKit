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

    func _drawGitGraph(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .gitGraph(pg) = positioned.content else { return }

        context.saveGState()
        defer { context.restoreGState() }

        let contentWidth = pg.width
        let contentHeight = pg.height

        // Theme-derived colors
        let lineColor = theme.effectiveLine().cgColor
        let surfaceColor = theme.effectiveSurface().cgColor
        let borderColor = theme.effectiveBorder().cgColor
        let accentColor = theme.effectiveAccent().cgColor
        let mutedColor = theme.effectiveMuted().cgColor
        let textColor = theme.foreground

        _withFittedContext(context, bounds: bounds, contentWidth: max(1, contentWidth), contentHeight: max(1, contentHeight)) { ctx in

            let useReduxGeometry = _gitGraphIsReduxGeometry(pg.themeName)
            let bulletRadius: CGFloat = useReduxGeometry ? 7 : 10
            let innerRadius: CGFloat = useReduxGeometry ? 5 : 6
            let crossConst: CGFloat = useReduxGeometry ? 4 : 5
            let highlightOuterSize: CGFloat = useReduxGeometry ? 14 : 20
            let highlightInnerSize: CGFloat = useReduxGeometry ? 8 : 12
            let highlightOuterOffset: CGFloat = useReduxGeometry ? 3 : 0
            let highlightInnerOffset: CGFloat = useReduxGeometry ? 2 : 0

            // Title
            if let title = pg.title {
                ctx.saveGState()
                _drawTextInFlipped(
                    title.text,
                    at: CGPoint(x: title.x, y: title.y),
                    context: ctx,
                    contentHeight: contentHeight,
                    color: textColor,
                    font: _monoFont(size: 18),
                    alignment: .center
                )
                ctx.restoreGState()
            }

            // Branch lines
            if pg.config.showBranches {
                for bl in pg.branchLines {
                    ctx.saveGState()
                    ctx.setStrokeColor(mutedColor)
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
                ctx.setFillColor(surfaceColor)
                ctx.addPath(roundedPath)
                ctx.fillPath()
                ctx.setStrokeColor(borderColor)
                ctx.addPath(roundedPath)
                ctx.strokePath()

                _drawTextInFlipped(
                    bl.text,
                    at: CGPoint(x: bl.x, y: bl.y),
                    context: ctx,
                    contentHeight: contentHeight,
                    color: textColor,
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
                    let outerRect = CGRect(x: cx - 10 + highlightOuterOffset, y: cy - 10 + highlightOuterOffset, width: highlightOuterSize, height: highlightOuterSize)
                    ctx.setFillColor(lineColor)
                    ctx.fill(outerRect)
                    let innerRect = CGRect(x: cx - 6 + highlightInnerOffset, y: cy - 6 + highlightInnerOffset, width: highlightInnerSize, height: highlightInnerSize)
                    ctx.setFillColor(accentColor)
                    ctx.fill(innerRect)

                case .cherryPick:
                    ctx.setFillColor(lineColor)
                    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: bulletRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    ctx.fillPath()
                    // Knockout color: deliberately fixed white so the inner pips
                    // and "M" mark read against the dark commit dot in both
                    // light AND dark themes. Using `bgColor` here would make
                    // them invisible on dark themes.
                    ctx.setFillColor(BMColor.white.cgColor)
                    let dotR: CGFloat = useReduxGeometry ? 2.5 : 2.75
                    ctx.addArc(center: CGPoint(x: cx - 3, y: cy + 2), radius: dotR, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    ctx.fillPath()
                    ctx.addArc(center: CGPoint(x: cx + 3, y: cy + 2), radius: dotR, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    ctx.fillPath()
                    ctx.setStrokeColor(BMColor.white.cgColor)
                    ctx.setLineWidth(1.5)
                    ctx.move(to: CGPoint(x: cx + 3, y: cy + 1))
                    ctx.addLine(to: CGPoint(x: cx, y: cy - 5))
                    ctx.strokePath()
                    ctx.move(to: CGPoint(x: cx - 3, y: cy + 1))
                    ctx.addLine(to: CGPoint(x: cx, y: cy - 5))
                    ctx.strokePath()

                case .merge:
                    ctx.setFillColor(lineColor)
                    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: bulletRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    ctx.fillPath()
                    // Same knockout-vs-theme reasoning as cherry-pick above.
                    ctx.setFillColor(BMColor.white.cgColor)
                    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: innerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    ctx.fillPath()

                case .reverse:
                    ctx.setStrokeColor(lineColor)
                    ctx.setLineWidth(2)
                    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: bulletRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    ctx.strokePath()
                    ctx.move(to: CGPoint(x: cx - crossConst, y: cy - crossConst))
                    ctx.addLine(to: CGPoint(x: cx + crossConst, y: cy + crossConst))
                    ctx.strokePath()
                    ctx.move(to: CGPoint(x: cx + crossConst, y: cy - crossConst))
                    ctx.addLine(to: CGPoint(x: cx - crossConst, y: cy + crossConst))
                    ctx.strokePath()

                default:
                    ctx.setFillColor(lineColor)
                    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: bulletRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    ctx.fillPath()
                }

                ctx.restoreGState()
            }

            // Commit labels
            if pg.config.showCommitLabel {
                for commit in pg.commits where commit.showLabel {
                    ctx.saveGState()
                    let isVertical = pg.direction == .TB || pg.direction == .BT
                    let labelRect = _gitGraphCommitLabelRect(commit, isVertical: isVertical)

                    if !isVertical && pg.config.rotateCommitLabel {
                        ctx.translateBy(x: commit.x, y: commit.y)
                        ctx.rotate(by: -.pi / 4)
                        ctx.translateBy(x: -commit.x, y: -commit.y)
                    }

                    ctx.setFillColor(surfaceColor)
                    ctx.fill(labelRect)
                    _drawTextInFlipped(
                        commit.id,
                        at: CGPoint(x: labelRect.minX + 8, y: labelRect.midY),
                        context: ctx,
                        contentHeight: contentHeight,
                        color: textColor,
                        font: _monoFont(size: 10),
                        alignment: .left
                    )
                    ctx.restoreGState()
                }
            }

            // Commit tags
            for commit in pg.commits where !commit.tags.isEmpty {
                let isVertical = pg.direction == .TB || pg.direction == .BT
                for (tagIndex, tag) in commit.tags.reversed().enumerated() {
                    ctx.saveGState()
                    let tagWidth = Double(max(tag.count, 1)) * 7 + 22
                    let tagHeight: Double = 16

                    if isVertical {
                        let yOrigin = commit.y - 16 - Double(tagIndex) * 20
                        let xOrigin = commit.x + 20
                        _applyGitGraphSvgTransform(
                            ctx,
                            translateX: 12,
                            translateY: 12,
                            angle: .pi / 4,
                            anchor: CGPoint(x: commit.x, y: yOrigin)
                        )
                        let tagPath = _gitGraphVerticalTagPath(
                            xOrigin: xOrigin,
                            yOrigin: yOrigin,
                            width: tagWidth,
                            height: tagHeight
                        )
                        ctx.setFillColor(surfaceColor)
                        ctx.addPath(tagPath)
                        ctx.fillPath()
                        ctx.setStrokeColor(borderColor)
                        ctx.setLineWidth(0.5)
                        ctx.addPath(tagPath)
                        ctx.strokePath()
                        ctx.setFillColor(borderColor)
                        ctx.addArc(center: CGPoint(x: xOrigin + 2, y: yOrigin), radius: 1.5, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                        ctx.fillPath()

                        _drawTextInFlipped(
                            tag,
                            at: CGPoint(x: xOrigin + 8, y: yOrigin),
                            context: ctx,
                            contentHeight: contentHeight,
                            color: textColor,
                            font: _monoFont(size: 8),
                            alignment: .left
                        )
                    } else {
                        let tagX = commit.x - tagWidth / 2
                        let tagY = commit.y - 34 - Double(tagIndex) * 20
                        let tagPath = _gitGraphHorizontalTagPath(
                            x: tagX,
                            y: tagY,
                            width: tagWidth,
                            height: tagHeight
                        )
                        ctx.setFillColor(surfaceColor)
                        ctx.addPath(tagPath)
                        ctx.fillPath()
                        ctx.setStrokeColor(borderColor)
                        ctx.setLineWidth(0.5)
                        ctx.addPath(tagPath)
                        ctx.strokePath()
                        ctx.setFillColor(borderColor)
                        ctx.addArc(center: CGPoint(x: tagX + 7, y: tagY + tagHeight / 2), radius: 1.5, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                        ctx.fillPath()

                        _drawTextInFlipped(
                            tag,
                            at: CGPoint(x: tagX + 14, y: tagY + tagHeight / 2),
                            context: ctx,
                            contentHeight: contentHeight,
                            color: textColor,
                            font: _monoFont(size: 8),
                            alignment: .left
                        )
                    }
                    ctx.restoreGState()
                }
            }

            // Arrows
            for arrow in pg.arrows {
                ctx.saveGState()
                ctx.setStrokeColor(lineColor)
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

    private func _gitGraphCommitLabelRect(_ commit: PositionedGitGraphCommit, isVertical: Bool) -> CGRect {
        let labelLen = Double(commit.id.count) * 4
        if isVertical {
            let lx = commit.x - labelLen * 2 - 20
            let ly = commit.y
            return CGRect(x: lx - 4, y: ly - 8, width: labelLen * 4 + 8, height: 16)
        }

        let lx = commit.x - labelLen
        let ly = commit.y + 20
        return CGRect(x: lx - 4, y: ly - 4, width: labelLen * 2 + 8, height: 18)
    }

    private func _applyGitGraphSvgTransform(
        _ ctx: CGContext,
        translateX: Double,
        translateY: Double,
        angle: CGFloat,
        anchor: CGPoint
    ) {
        ctx.translateBy(x: translateX, y: translateY)
        ctx.translateBy(x: anchor.x, y: anchor.y)
        ctx.rotate(by: angle)
        ctx.translateBy(x: -anchor.x, y: -anchor.y)
    }

    private func _gitGraphHorizontalTagPath(x: Double, y: Double, width: Double, height: Double) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y + height / 2))
        path.addLine(to: CGPoint(x: x + 8, y: y))
        path.addLine(to: CGPoint(x: x + width, y: y))
        path.addLine(to: CGPoint(x: x + width, y: y + height))
        path.addLine(to: CGPoint(x: x + 8, y: y + height))
        path.closeSubpath()
        return path
    }

    private func _gitGraphVerticalTagPath(xOrigin: Double, yOrigin: Double, width: Double, height: Double) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: xOrigin, y: yOrigin + 2))
        path.addLine(to: CGPoint(x: xOrigin, y: yOrigin - 2))
        path.addLine(to: CGPoint(x: xOrigin + 10, y: yOrigin - height / 2 - 2))
        path.addLine(to: CGPoint(x: xOrigin + 10 + width, y: yOrigin - height / 2 - 2))
        path.addLine(to: CGPoint(x: xOrigin + 10 + width, y: yOrigin + height / 2 + 2))
        path.addLine(to: CGPoint(x: xOrigin + 10, y: yOrigin + height / 2 + 2))
        path.closeSubpath()
        return path
    }
}
#endif
