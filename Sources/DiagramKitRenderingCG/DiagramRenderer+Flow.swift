// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import DiagramKitCommon
import CoreGraphics
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

private typealias ParsedArrowHeadType = original_src_types.ArrowHeadType

private func _mapArrowHead(_ type: ParsedArrowHeadType) -> ArrowHead {
    switch type {
    case .none: return .none
    case .arrow: return .arrow
    case .open: return .open
    case .circle: return .circle
    case .cross: return .cross
    case .diamond: return .diamond
    }
}

/// Parse a CSS length value like "2px", "1.5", "3pt" into a CGFloat.
func _parseCSSLength(_ value: String) -> CGFloat? {
    let stripped = value.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "px", with: "")
        .replacingOccurrences(of: "pt", with: "")
    return Double(stripped).map { CGFloat($0) }
}

extension DiagramRenderer {

    func _drawFlowOrState(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard
            let nodes = positioned.flowchartNodes,
            let edges = positioned.flowchartEdges,
            !nodes.isEmpty
        else { return }

        let groups = positioned.flowchartGroups ?? []

        _withFittedContext(context, bounds: bounds, contentWidth: max(1, positioned.width), contentHeight: max(1, positioned.height)) { ctx in
            // Context already has y=0 at top (UIKit native, or AppKit flipped by MermaidView).
            // No internal flip needed — layout coordinates match the context.
            let ch = max(1, positioned.height)

            // 1. Subgraph backgrounds
            self._drawSubgraphBackgrounds(groups, in: ctx)

            // 2. Draw edges (lines only)
            for edge in edges {
                let pts = edge.points.map { CGPoint(x: $0.x, y: $0.y) }
                var style = EdgeStyleParser.parse(from: edge.style, arrowHeadStart: _mapArrowHead(edge.arrowHeadStart), arrowHeadEnd: _mapArrowHead(edge.arrowHeadEnd))
                if style.lineStyle == .invisible { continue }
                style.color = edge.inlineStyle?["stroke"]
                style.strokeWidth = edge.inlineStyle?["stroke-width"].flatMap { _parseCSSLength($0) }
                let curve = edge.curve?.isEmpty == false ? edge.curve : nil
                self.edgeRenderer.drawEdgePath(points: pts, style: style, in: ctx, theme: self.theme, curveType: curve)
            }

            // 3. Draw arrow heads
            for edge in edges {
                let pts = edge.points.map { CGPoint(x: $0.x, y: $0.y) }
                var style = EdgeStyleParser.parse(from: edge.style, arrowHeadStart: _mapArrowHead(edge.arrowHeadStart), arrowHeadEnd: _mapArrowHead(edge.arrowHeadEnd))
                if style.lineStyle == .invisible { continue }
                style.color = edge.inlineStyle?["stroke"]
                style.strokeWidth = edge.inlineStyle?["stroke-width"].flatMap { _parseCSSLength($0) }
                self.edgeRenderer.drawArrowHeads(points: pts, style: style, in: ctx, theme: self.theme)
            }

            // 4. Draw node shapes
            for node in nodes {
                let rect = CGRect(x: node.x, y: node.y, width: node.width, height: node.height)
                self.shapeRenderer.drawShape(node.shape, bounds: rect, inlineStyles: node.inlineStyle, in: ctx, theme: self.theme)
            }

            // 4b. Draw icon/image content inside nodes
            for node in nodes {
                guard let props = node.properties else { continue }
                let iconShapes = Set(["icon-square", "icon-circle", "icon", "icon-rounded", "image-square"])
                guard iconShapes.contains(node.shape) else { continue }
                let rect = CGRect(x: node.x, y: node.y, width: node.width, height: node.height)
                self._drawIconOrImage(props: props, bounds: rect, in: ctx, contentHeight: ch)
            }

            // 5. Draw node labels
            for node in nodes {
                guard !node.label.isEmpty else { continue }
                let textColor = self.theme.nodeTextColor(for: node.inlineStyle)
                let nodeFont = self.fontResolver.nodeLabelFont()
                let hasMarkdown = node.label.contains("**") || node.label.contains("*") || node.label.contains("`")
                let pos = node.properties?.pos

                // Label positioned relative to node when pos is set on icon/image shapes
                let labelCenter = _labelCenterForNode(node, pos: pos)
                if node.shape == "rect-with-title", node.descriptions.count > 1 {
                    let titleCenter = CGPoint(x: node.x + node.width / 2, y: node.y + 12)
                    self._drawTextInFlipped(
                        node.descriptions[0],
                        at: titleCenter,
                        context: ctx,
                        contentHeight: ch,
                        color: textColor,
                        font: nodeFont,
                        alignment: .center
                    )
                    let bodyRect = CGRect(x: node.x, y: node.y + 24, width: node.width, height: node.height - 24)
                    let inset = bodyRect.insetBy(dx: 4, dy: 2)
                    self.labelRenderer.drawMultilineText(
                        node.descriptions.dropFirst().joined(separator: "\n"),
                        in: inset,
                        context: ctx,
                        color: textColor,
                        font: nodeFont,
                        alignment: .center
                    )
                    continue
                }
                if hasMarkdown {
                    let mdConfig = MarkdownLabelRenderer.Config(fontSize: nodeFont.pointSize, textColor: textColor)
                    let attrStr = MarkdownLabelRenderer.render(node.label, config: mdConfig)
                    let rect = CGRect(x: node.x, y: node.y, width: node.width, height: node.height)
                    let inset = rect.insetBy(dx: 4, dy: 2)
                    self._drawAttributedStringInFlipped(attrStr, in: inset, context: ctx, contentHeight: ch, alignment: .center)
                    continue
                }
                if node.label.contains("\n") {
                    let rect = CGRect(x: node.x, y: node.y, width: node.width, height: node.height)
                    let inset = rect.insetBy(dx: 4, dy: 2)
                    self.labelRenderer.drawMultilineText(
                        node.label,
                        in: inset,
                        context: ctx,
                        color: textColor,
                        font: nodeFont,
                        alignment: .center
                    )
                } else {
                    let center = pos != nil ? labelCenter : CGPoint(x: node.x + node.width / 2, y: node.y + node.height / 2)
                    self._drawTextInFlipped(
                        node.label,
                        at: center,
                        context: ctx,
                        contentHeight: ch,
                        color: textColor,
                        font: nodeFont,
                        alignment: .center
                    )
                }
            }

            // 6. Draw edge labels (on top of nodes so they're not occluded)
            for edge in edges {
                if let label = edge.label, !label.isEmpty, let lp = edge.labelPosition {
                    self._drawEdgeLabelInFlipped(label, at: CGPoint(x: lp.x, y: lp.y), in: ctx, contentHeight: ch)
                }
            }

            // 7. Subgraph labels
            self._drawSubgraphLabelsInFlipped(groups, in: ctx, contentHeight: ch)
        }
    }

    private func _drawSubgraphBackgrounds(_ groups: [_PositionedGroupPayload], in context: CGContext) {
        for group in groups {
            let rect = CGRect(x: group.x, y: group.y, width: group.width, height: group.height)
            let path = BMBezierPath(rect: rect)

            // Fill background
            context.setFillColor(theme.subgraphBackgroundColor().cgColor)
            context.addPath(path.bm_cgPath)
            context.fillPath()

            // Fill header band at top of group box
            let headerY = group.y
            let headerRect = CGRect(x: group.x, y: headerY, width: group.width, height: group.headerHeight)
            let headerPath = BMBezierPath(roundedRect: headerRect, cornerRadius: 0)
            context.setFillColor(theme.subgraphHeaderColor().cgColor)
            context.addPath(headerPath.bm_cgPath)
            context.fillPath()

            // Stroke border
            context.setStrokeColor(theme.effectiveBorder().cgColor)
            context.setLineWidth(1.0)
            context.addPath(path.bm_cgPath)
            context.strokePath()

            // Header bottom line
            let headerBottom = headerY + group.headerHeight
            context.move(to: CGPoint(x: group.x, y: headerBottom))
            context.addLine(to: CGPoint(x: group.x + group.width, y: headerBottom))
            context.strokePath()

            // Recurse into children
            _drawSubgraphBackgrounds(group.children, in: context)
        }
    }

    private func _drawSubgraphLabels(_ groups: [_PositionedGroupPayload], in context: CGContext) {
        let headerFont = self.fontResolver.groupHeaderFont()
        for group in groups {
            if group.label.contains("\n") {
                let rect = CGRect(x: group.x + 8, y: group.y, width: group.width - 16, height: group.headerHeight)
                labelRenderer.drawMultilineText(group.label, in: rect, context: context, color: theme.effectiveTextSecondary(), font: headerFont, alignment: .center)
            } else {
                let labelPoint = CGPoint(x: group.x + 8, y: group.y + group.headerHeight / 2)
                labelRenderer.drawText(group.label, at: labelPoint, context: context, color: theme.effectiveTextSecondary(), font: headerFont, alignment: .left)
            }
            _drawSubgraphLabels(group.children, in: context)
        }
    }

    private func _drawSubgraphLabelsInFlipped(_ groups: [_PositionedGroupPayload], in context: CGContext, contentHeight ch: CGFloat) {
        let headerFont = self.fontResolver.groupHeaderFont()
        for group in groups {
            let labelPoint = CGPoint(x: group.x + 8, y: group.y + group.headerHeight / 2)
            _drawTextInFlipped(
                group.label,
                at: labelPoint,
                context: context,
                contentHeight: ch,
                color: theme.effectiveTextSecondary(),
                font: headerFont,
                alignment: .left
            )
            _drawSubgraphLabelsInFlipped(group.children, in: context, contentHeight: ch)
        }
    }

    func _drawEdgeLabelInFlipped(_ label: String, at position: CGPoint, in context: CGContext, contentHeight ch: CGFloat) {
        let edgeFont = self.fontResolver.edgeLabelFont()
        let attributes: [NSAttributedString.Key: Any] = [.font: edgeFont]
        let size = (label as NSString).size(withAttributes: attributes)

        let padding = self.tokens.edgeLabelPadding
        let pillRect = CGRect(
            x: position.x - size.width / 2 - padding,
            y: position.y - size.height / 2 - padding / 2,
            width: size.width + padding * 2,
            height: size.height + padding
        )

        let pillPath = BMBezierPath(roundedRect: pillRect, cornerRadius: self.tokens.edgeLabelCornerRadius)
        context.setFillColor(theme.background.cgColor)
        context.addPath(pillPath.bm_cgPath)
        context.fillPath()

        context.setStrokeColor(theme.effectiveInnerStroke().cgColor)
        context.setLineWidth(self.tokens.edgeLabelBorderWidth)
        context.addPath(pillPath.bm_cgPath)
        context.strokePath()

        _drawTextInFlipped(
            label,
            at: position,
            context: context,
            contentHeight: ch,
            color: theme.effectiveTextSecondary(),
            font: edgeFont,
            alignment: .center
        )
    }

    func _drawEdgeLabel(_ label: String, at position: CGPoint, in context: CGContext) {
        let edgeFont = self.fontResolver.edgeLabelFont()
        let attributes: [NSAttributedString.Key: Any] = [.font: edgeFont]
        let size = (label as NSString).size(withAttributes: attributes)

        let padding = self.tokens.edgeLabelPadding
        let pillRect = CGRect(
            x: position.x - size.width / 2 - padding,
            y: position.y - size.height / 2 - padding / 2,
            width: size.width + padding * 2,
            height: size.height + padding
        )

        let pillPath = BMBezierPath(roundedRect: pillRect, cornerRadius: self.tokens.edgeLabelCornerRadius)
        context.setFillColor(theme.background.cgColor)
        context.addPath(pillPath.bm_cgPath)
        context.fillPath()

        context.setStrokeColor(theme.effectiveInnerStroke().cgColor)
        context.setLineWidth(self.tokens.edgeLabelBorderWidth)
        context.addPath(pillPath.bm_cgPath)
        context.strokePath()

        labelRenderer.drawText(
            label,
            at: position,
            context: context,
            color: theme.effectiveTextSecondary(),
            font: edgeFont,
            alignment: .center
        )
    }

    private func _labelCenterForNode(_ node: _PositionedNodePayload, pos: String?) -> CGPoint {
        guard let pos else { return CGPoint(x: node.x + node.width / 2, y: node.y + node.height / 2) }
        switch pos.lowercased() {
        case "t":
            return CGPoint(x: node.x + node.width / 2, y: node.y - 12)
        case "b":
            return CGPoint(x: node.x + node.width / 2, y: node.y + node.height + 12)
        case "l":
            return CGPoint(x: node.x - 12, y: node.y + node.height / 2)
        case "r":
            return CGPoint(x: node.x + node.width + 12, y: node.y + node.height / 2)
        default:
            return CGPoint(x: node.x + node.width / 2, y: node.y + node.height / 2)
        }
    }

    func _drawIconOrImage(props: original_src_types.NodeProperties, bounds: CGRect, in context: CGContext, contentHeight ch: CGFloat) {
        if let iconName = props.icon, !iconName.isEmpty {
            let faName = iconName.hasPrefix("fa:") ? String(iconName.dropFirst(3)) : iconName
            if let sfName = FontAwesomeMap.sfSymbolName(for: faName) {
                _drawSFIcon(sfName, bounds: bounds.insetBy(dx: 4, dy: 4), in: context, contentHeight: ch)
            } else {
                let fontSize = CGFloat(min(bounds.width, bounds.height) * 0.4)
                let iconFont = self.fontResolver.proportionalFont(size: fontSize, weight: .regular)
                let textColor = theme.nodeTextColor(for: [:])
                _drawTextInFlipped(
                    faName,
                    at: CGPoint(x: bounds.midX, y: bounds.midY),
                    context: context,
                    contentHeight: ch,
                    color: textColor,
                    font: iconFont,
                    alignment: .center
                )
            }
        }
    }

    private func _drawSFIcon(_ sfName: String, bounds: CGRect, in context: CGContext, contentHeight ch: CGFloat) {
        #if os(macOS)
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: min(bounds.width, bounds.height) * 0.6, weight: .regular)
            guard let image = NSImage(systemSymbolName: sfName, accessibilityDescription: nil) else { return }
            guard let symbol = image.withSymbolConfiguration(config) else { return }
            let drawRect = CGRect(
                x: bounds.midX - bounds.width / 2,
                y: bounds.midY - bounds.height / 2,
                width: bounds.width,
                height: bounds.height
            )
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            symbol.draw(in: drawRect)
            NSGraphicsContext.restoreGraphicsState()
        }
        #else
        let config = UIImage.SymbolConfiguration(pointSize: min(bounds.width, bounds.height) * 0.6, weight: .regular)
        guard let symbol = UIImage(systemName: sfName, withConfiguration: config) else { return }
        symbol.draw(in: bounds)
        #endif
    }
}
#endif