// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitCommon
import DiagramKitModel
import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension DiagramRenderer {

    func _drawBlock(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case .block(let diagram) = positioned.content else { return }

        _withFittedContext(context, bounds: bounds, contentWidth: diagram.bounds.width, contentHeight: diagram.bounds.height) { ctx in
            ctx.translateBy(x: -diagram.bounds.x, y: -diagram.bounds.y)

            for edge in diagram.edges {
                _drawBlockCgEdge(edge, in: ctx)
            }

            for block in diagram.blocks {
                _drawBlockCgNode(block, in: ctx)
            }
        }
    }

    private func _drawBlockCgNode(_ node: PositionedBlockNode, in ctx: CGContext) {
        if node.type == .space || node.type == .columnSetting { return }

        let x = node.x - node.width / 2
        let y = node.y - node.height / 2

        let fillColor = _cgBlockFill(node)
        let strokeColor = _cgBlockStroke(node)
        ctx.setFillColor(fillColor.cgColor)
        ctx.setStrokeColor(strokeColor.cgColor)
        ctx.setLineWidth(CGFloat(BlockRenderConstants.strokeWidth))

        if node.type == .composite {
            let clusterRect = CGRect(x: x, y: y + 20, width: node.width, height: max(0, node.height - 20))
            ctx.setFillColor(fillColor.withAlphaComponent(0.1).cgColor)
            ctx.fill(clusterRect)
            ctx.stroke(clusterRect)
            _drawTextInFlipped(node.label, at: CGPoint(x: node.x, y: y + 12), context: ctx, contentHeight: 0, color: strokeColor, font: _monoFont(size: 12))
            for child in node.children {
                _drawBlockCgNode(child, in: ctx)
            }
        } else if node.type == .blockArrow {
            _drawBlockArrowCg(node: node, in: ctx)
        } else {
            let rect = CGRect(x: x, y: y, width: node.width, height: node.height)
            shapeRenderer.drawShape(_cgBlockShapeName(node.type), bounds: rect, inlineStyles: _cgBlockInlineStyles(node), in: ctx, theme: theme)

            _drawTextInFlipped(node.label, at: CGPoint(x: node.x, y: y + node.height / 2), context: ctx, contentHeight: 0, color: _cgBlockTextColor(node), font: _monoFont(size: 12))
        }
    }

    private func _drawBlockArrowCg(node: PositionedBlockNode, in ctx: CGContext) {
        let w = node.width
        let h = node.height
        let padding = 8.0
        let dirs = node.directions ?? [.right]
        let points = getBlockArrowPoints(directions: dirs, width: w, height: h, padding: padding)
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? CGFloat(w)
        let minY = points.map(\.y).min() ?? -CGFloat(h)
        let maxY = points.map(\.y).max() ?? 0
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        let path = CGMutablePath()
        for (i, p) in points.enumerated() {
            let pt = CGPoint(x: CGFloat(node.x) + p.x - centerX, y: CGFloat(node.y) + p.y - centerY)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()

        ctx.addPath(path)
        let fill = _cgBlockFill(node)
        let stroke = _cgBlockStroke(node)
        ctx.setFillColor(fill.cgColor)
        ctx.setStrokeColor(stroke.cgColor)
        ctx.drawPath(using: .fillStroke)

        _drawTextInFlipped(node.label, at: CGPoint(x: node.x, y: node.y), context: ctx, contentHeight: 0, color: _cgBlockTextColor(node), font: _monoFont(size: 12))
    }

    private func _drawBlockCgEdge(_ edge: PositionedBlockEdge, in ctx: CGContext) {
        guard edge.points.count >= 3 else { return }
        let pts = edge.points

        let midpoint = pts[1]
        let points = [
            CGPoint(x: pts[0].x, y: pts[0].y),
            CGPoint(x: midpoint.x, y: midpoint.y),
            CGPoint(x: pts[2].x, y: pts[2].y),
        ]
        let style = EdgeStyle(
            lineStyle: edge.thickness == "thick" ? .thick : (edge.pattern == "dotted" ? .dotted : .solid),
            sourceArrow: _cgBlockArrowHead(edge.arrowTypeStart),
            targetArrow: _cgBlockArrowHead(edge.arrowTypeEnd),
            strokeWidth: edge.thickness == "thick"
                ? CGFloat(BlockRenderConstants.thickStrokeWidth)
                : CGFloat(BlockRenderConstants.strokeWidth)
        )
        edgeRenderer.drawEdgePath(points: points, style: style, in: ctx, theme: theme)
        edgeRenderer.drawArrowHeads(points: points, style: style, in: ctx, theme: theme)

        if let label = edge.label, !label.isEmpty {
            let font = _monoFont(size: 11)
            _drawTextInFlipped(label, at: CGPoint(x: points[1].x, y: points[1].y + 5), context: ctx, contentHeight: 0, color: theme.foreground, font: font)
        }
    }

    private func _cgBlockFill(_ node: PositionedBlockNode) -> BMColor {
        if let hex = BlockStyleDecoder.fillHex(from: node.styles) {
            return BMColor(hex: hex)
        }
        return BMColor(hex: "#e8f0fe")
    }

    private func _cgBlockStroke(_ node: PositionedBlockNode) -> BMColor {
        if let hex = BlockStyleDecoder.strokeHex(from: node.styles) {
            return BMColor(hex: hex)
        }
        return theme.border ?? theme.foreground
    }

    private func _cgBlockTextColor(_ node: PositionedBlockNode) -> BMColor {
        if let hex = BlockStyleDecoder.textColorHex(labelStyle: node.labelStyle, styles: node.styles) {
            return BMColor(hex: hex)
        }
        return theme.foreground
    }

    private func _cgBlockInlineStyles(_ node: PositionedBlockNode) -> [String: String] {
        var result: [String: String] = [:]
        for style in node.styles {
            let parts = style.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            result[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
        }
        return result
    }

    private func _cgBlockShapeName(_ type: BlockNodeType) -> String {
        BlockShapeMapper.shapeSpecName(for: type)
    }

    private func _cgBlockArrowHead(_ type: String) -> ArrowHead {
        switch BlockEdgeArrowheadKind(rawArrowType: type) {
        case .point:  return .arrow
        case .circle: return .circle
        case .cross:  return .cross
        case .none:   return .none
        }
    }
}
#endif
