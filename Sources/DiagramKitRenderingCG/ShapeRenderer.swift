// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import CoreGraphics

public class NodeShapeRenderer {

    let config: RenderConfig

    /// Token storage backed by the renderer's configuration.
    var tokens: RenderTokens { config.tokens }

    public init(config: RenderConfig = RenderConfig.shared) {
        self.config = config
    }

    public func drawShape(_ shape: String, bounds: CGRect, inlineStyles: [String: String], in context: CGContext, theme: DiagramTheme) {
        context.saveGState()

        if shape == "state-end" {
            let cx = bounds.midX, cy = bounds.midY
            let outerR = min(bounds.width, bounds.height) / 2 - 2
            let outerRect = CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2)
            context.setStrokeColor(theme.foreground.cgColor)
            context.setLineWidth(tokens.strokeWidthInnerBox * 2)
            context.strokeEllipse(in: outerRect)
            let innerR = outerR - 4
            let innerRect = CGRect(x: cx - innerR, y: cy - innerR, width: innerR * 2, height: innerR * 2)
            context.setFillColor(theme.foreground.cgColor)
            context.fillEllipse(in: innerRect)
            context.restoreGState()
            return
        }

        if shape == "state-divider" {
            let y = bounds.midY
            let grey = theme.effectiveBorder()
            context.setStrokeColor(grey.cgColor)
            context.setAlpha(0.6)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [5, 5])
            context.move(to: CGPoint(x: bounds.minX, y: y))
            context.addLine(to: CGPoint(x: bounds.maxX, y: y))
            context.strokePath()
            context.restoreGState()
            return
        }

        let fillColor: BMColor
        let strokeColor: BMColor
        let path = shapePath(for: shape, in: bounds)

        // Apply fill/stroke overrides from ShapeSpec.
        let spec = ShapeSpecRegistry.spec(for: shape)
        if let fo = spec.fillOverride {
            switch fo {
            case .foreground: fillColor = theme.foreground
            case .surface:    fillColor = theme.subgraphHeaderColor()
            case .inherit:    fillColor = theme.nodeFillColor(for: inlineStyles)
            case .none:       fillColor = theme.nodeFillColor(for: inlineStyles)
            }
        } else {
            fillColor = theme.nodeFillColor(for: inlineStyles)
        }
        switch spec.strokeOverride {
        case .some(.none):
            strokeColor = .clear
        case .some, nil:
            strokeColor = theme.nodeStrokeColor(for: inlineStyles)
        }

        // Only fill if override doesn't suppress it. Use the cross-platform
        // `bmColorEquals` helper rather than `!=`: on AppKit, `NSColor.==`
        // is calibrated-color-space-sensitive, so a `BMColor(hex:)`-derived
        // clear (deviceRGB, alpha 0) is not equal to `NSColor.clear`
        // (calibratedWhite, alpha 0). `bmColorEquals` normalizes both to
        // deviceRGB before comparing components.
        if !fillColor.bmColorEquals(.clear) {
            context.setFillColor(fillColor.cgColor)
            context.addPath(path)
            context.fillPath()
        }

        // Only stroke if override doesn't suppress it.
        if !strokeColor.bmColorEquals(.clear) {
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(tokens.strokeWidthInnerBox)
            context.addPath(path)
            context.strokePath()
        }

        _drawSpecDecorations(shape, in: bounds, context: context, theme: theme, inlineStyles: inlineStyles)

        context.restoreGState()
    }

    public func shapePath(for shape: String, in bounds: CGRect) -> CGPath {
        let spec = ShapeSpecRegistry.spec(for: shape)
        return CGPathRenderer.makePath(from: spec.path(bounds, config), in: bounds, config: config)
    }

    // MARK: - Spec-driven decoration rendering

    /// Draws decorations declared in the shape's `ShapeSpec`.
    ///
    /// Each decoration computes its own sub-bounds via `decoration.bounds`
    /// so that position-dependent details (cylinder caps, offset copies,
    /// inset panes, corner tags) can coexist with same-bounds polylines
    /// and ellipses in a single loop.
    private func _drawSpecDecorations(_ shape: String, in fullBounds: CGRect, context: CGContext, theme: DiagramTheme, inlineStyles: [String: String]) {
        let spec = ShapeSpecRegistry.spec(for: shape)
        guard !spec.decorations.isEmpty else { return }

        let strokeColor = theme.nodeStrokeColor(for: inlineStyles)
        let fillColor = theme.nodeFillColor(for: inlineStyles)

        for decoration in spec.decorations {
            let subBounds = decoration.bounds(fullBounds, config)
            let decorationPath = decoration.path(subBounds, config)
            let cgPath = CGPathRenderer.makePath(from: decorationPath, in: subBounds, config: config)

            switch decoration.stroke {
            case .none:
                break
            case .mainStroke:
                context.setStrokeColor(strokeColor.cgColor)
                context.setLineWidth(tokens.strokeWidthInnerBox)
                context.addPath(cgPath)
                context.strokePath()
            case .dashed(let lengths):
                context.setStrokeColor(strokeColor.cgColor)
                context.setLineWidth(tokens.strokeWidthInnerBox)
                context.setLineDash(phase: 0, lengths: lengths.map { $0 })
                context.addPath(cgPath)
                context.strokePath()
                context.setLineDash(phase: 0, lengths: [])
            case .thinStroke:
                context.saveGState()
                context.setStrokeColor(strokeColor.cgColor)
                context.setLineWidth(tokens.strokeWidthInnerBox)
                context.setAlpha(0.4)
                context.addPath(cgPath)
                context.strokePath()
                context.restoreGState()
            }

            switch decoration.fill {
            case .none:
                break
            case .inherit:
                context.setFillColor(fillColor.cgColor)
                context.addPath(cgPath)
                context.fillPath()
            case .surface:
                context.setFillColor(theme.subgraphHeaderColor().cgColor)
                context.addPath(cgPath)
                context.fillPath()
            case .foreground:
                context.setFillColor(theme.foreground.cgColor)
                context.addPath(cgPath)
                context.fillPath()
            }
        }
    }


}
#endif
