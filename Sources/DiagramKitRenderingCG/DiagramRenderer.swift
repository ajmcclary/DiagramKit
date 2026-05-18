// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import CoreGraphics
import CoreText
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public final class DiagramRenderer {
    public var theme: DiagramTheme
    let config: RenderConfig

    /// Font resolver backed by the renderer's configuration.
    /// Prefer `self.fontResolver` over `self._monoFont` / `self._italicSystemFont`
    /// in new code. The legacy helpers below delegate here for backward compat.
    var fontResolver: DiagramKitModel.DiagramFontResolver { config.fontResolver }

    /// Token storage backed by the renderer's configuration.
    /// Prefer `self.tokens.strokeWidthOuterBox` over `self.config.strokeWidthOuterBox`
    /// in new code.
    var tokens: RenderTokens { config.tokens }

    /// Text measurement backed by the renderer's configuration.
    /// Prefer `self.textMetrics.estimateTextWidth(...)` over
    /// `self.config.estimateTextWidth(...)` in new code.
    var textMetrics: TextMetrics { config.textMetrics }

    let shapeRenderer: NodeShapeRenderer
    let edgeRenderer: EdgeRenderer
    let labelRenderer: LabelRenderer

    public init(theme: DiagramTheme = .default, config: RenderConfig = RenderConfig.shared) {
        DiagramFontRegistry.registerBundledFontsIfNeeded()
        self.theme = theme
        self.config = config
        self.shapeRenderer = NodeShapeRenderer(config: config)
        self.edgeRenderer = EdgeRenderer(config: config)
        self.labelRenderer = LabelRenderer()
    }

    public func render(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        context.saveGState()
        defer { context.restoreGState() }

        if !theme.transparent {
            context.setFillColor(theme.background.cgColor)
            context.fill(bounds)
        }

        CGRenderRegistry.render(positioned, renderer: self, in: context, bounds: bounds)
    }

    // MARK: - Utility

    /// Resolves a monospace font. Delegates to `fontResolver.monoFont(size:)`.
    func _monoFont(size: CGFloat) -> BMFont {
        fontResolver.monoFont(size: size)
    }

    /// Resolves an italic proportional font.
    /// Delegates to `fontResolver.italicProportionalFont(size:weight:)`.
    func _italicSystemFont(size: CGFloat, weight: CGFloat) -> BMFont {
        fontResolver.italicProportionalFont(size: size, weight: weight)
    }

    /// Resolves an italic monospace font.
    /// Delegates to `fontResolver.italicMonoFont(size:)`.
    func _italicMonoFont(size: CGFloat) -> BMFont {
        fontResolver.italicMonoFont(size: size)
    }

    /// Draw text at a point. The `contentHeight` parameter is retained for call-site compatibility
    /// but is no longer used (the context is already y=0 at top).
    func _drawTextInFlipped(
        _ text: String,
        at point: CGPoint,
        context: CGContext,
        contentHeight: CGFloat,
        color: BMColor,
        font: BMFont,
        alignment: TextAlignment = .center
    ) {
        guard !text.isEmpty else { return }
        if text.contains("\n") {
            let extent = labelRenderer.measureMultilineExtent(text, font: font)
            let x: CGFloat
            switch alignment {
            case .left:
                x = point.x
            case .center:
                x = point.x - extent.width / 2
            case .right:
                x = point.x - extent.width
            }
            let rect = CGRect(
                x: x,
                y: point.y - extent.height / 2,
                width: extent.width,
                height: extent.height
            )
            labelRenderer.drawMultilineText(text, in: rect, context: context, color: color, font: font, alignment: alignment)
        } else {
            labelRenderer.drawText(text, at: point, context: context, color: color, font: font, alignment: alignment)
        }
    }

    func _drawAttributedStringInFlipped(
        _ attrStr: NSAttributedString,
        in rect: CGRect,
        context: CGContext,
        contentHeight: CGFloat,
        alignment: TextAlignment = .center
    ) {
        guard attrStr.length > 0 else { return }
        let bounding = attrStr.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                            options: [.usesLineFragmentOrigin, .usesFontLeading])
        var drawRect = rect
        drawRect.size.height = bounding.height
        drawRect.origin.y = rect.midY - bounding.height / 2
        #if os(macOS)
        attrStr.draw(in: drawRect)
        #else
        attrStr.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        #endif
    }

    func _withFittedContext(
        _ context: CGContext,
        bounds: CGRect,
        contentWidth: Double,
        contentHeight: Double,
        draw: (CGContext) -> Void
    ) {
        let cw = max(1.0, contentWidth)
        let ch = max(1.0, contentHeight)
        let scale = min(bounds.width / cw, bounds.height / ch)
        let fittedWidth = cw * scale
        let fittedHeight = ch * scale
        let offsetX = bounds.minX + (bounds.width - fittedWidth) / 2
        let offsetY = bounds.minY + (bounds.height - fittedHeight) / 2

        context.saveGState()
        context.translateBy(x: offsetX, y: offsetY)
        context.scaleBy(x: scale, y: scale)
        draw(context)
        context.restoreGState()
    }
}
#endif
