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

        // Apply fill/stroke overrides from ShapeSpec when present.
        if let spec = ShapeSpecRegistry.spec(for: shape) {
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
        } else {
            fillColor = theme.nodeFillColor(for: inlineStyles)
            strokeColor = theme.nodeStrokeColor(for: inlineStyles)
        }

        // Only fill if override doesn't suppress it.
        if fillColor != .clear {
            context.setFillColor(fillColor.cgColor)
            context.addPath(path)
            context.fillPath()
        }

        // Only stroke if override doesn't suppress it.
        if strokeColor != .clear {
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(tokens.strokeWidthInnerBox)
            context.addPath(path)
            context.strokePath()
        }

        _drawSpecDecorations(shape, in: bounds, context: context, theme: theme, inlineStyles: inlineStyles)

        context.restoreGState()
    }

    public func shapePath(for shape: String, in bounds: CGRect) -> CGPath {
        // Route through ShapeSpecRegistry for all shapes with registry entries.
        // The fallback switch below is retained for shapes not yet in the
        // registry or for any edge case where registry lookup returns nil.
        if let spec = ShapeSpecRegistry.spec(for: shape) {
            let shapePath = spec.path(bounds, config)
            return CGPathRenderer.makePath(from: shapePath, in: bounds, config: config)
        }

        switch shape {
        case "rectangle", "entity", "invisible":
            return CGPath(rect: bounds, transform: nil)
        case "rounded":
            return roundedRectPath(bounds, cornerRadius: 6)
        case "stadium":
            return roundedRectPath(bounds, cornerRadius: bounds.height / 2)
        case "circle", "doublecircle", "state-choice":
            return CGPath(ellipseIn: bounds, transform: nil)
        case "state-start", "state-end":
            return trueCirclePath(bounds)
        case "state-divider":
            return CGPath(rect: bounds, transform: nil)
        case "state-note":
            return roundedRectPath(bounds, cornerRadius: 4)
        case "rounded-with-title":
            return roundedRectPath(bounds, cornerRadius: 8)
        case "rect-with-title":
            return roundedRectPath(bounds, cornerRadius: 4)
        case "diamond", "rhombus":
            return diamondPath(bounds)
        case "hexagon":
            return hexagonPath(bounds)
        case "parallelogram":
            return parallelogramPath(bounds)
        case "parallelogram-alt":
            return parallelogramAltPath(bounds)
        case "trapezoid":
            return trapezoidPath(bounds)
        case "trapezoid-alt":
            return trapezoidAltPath(bounds)
        case "cylinder":
            let ry = tokens.cylinderEllipseRadius
            let bodyRect = CGRect(x: bounds.minX, y: bounds.minY + ry, width: bounds.width, height: bounds.height - 2 * ry)
            return CGPath(rect: bodyRect, transform: nil)
        case "subroutine":
            return CGPath(rect: bounds, transform: nil)
        case "asymmetric":
            return asymmetricPath(bounds)
        case "ellipse":
            return CGPath(ellipseIn: bounds, transform: nil)
        case "state-fork":
            return CGPath(rect: bounds, transform: nil)
        case "class-box":
            return roundedRectPath(bounds, cornerRadius: 4)
        case "triangle", "notched-pentagon":
            return trianglePath(bounds)
        case "bang":
            return trueCirclePath(bounds)
        case "small-circle", "filled-circle":
            return trueCirclePath(bounds)
        case "framed-circle":
            return trueCirclePath(bounds)  // outer ring drawn in details
        case "fork", "join":
            return roundedRectPath(bounds, cornerRadius: 2)
        case "text":
            return CGPath(rect: bounds, transform: nil)
        case "cloud":
            return cloudPath(bounds)
        case "document", "tagged-document", "lined-document", "stacked-document":
            return documentPath(bounds)
        case "crossed-circle":
            return trueCirclePath(bounds)
        case "delay":
            return delayPath(bounds)
        case "notched-rectangle":
            return notchedRectPath(bounds)
        case "tagged-rectangle":
            return CGPath(rect: bounds, transform: nil)
        case "window-pane":
            return CGPath(rect: bounds, transform: nil)
        case "divided-rectangle":
            return CGPath(rect: bounds, transform: nil)
        case "hourglass":
            return hourglassPath(bounds)
        case "lightning-bolt":
            return lightningBoltPath(bounds)
        case "stacked-rectangle":
            return CGPath(rect: bounds, transform: nil)
        case "brace-l", "brace-r", "braces":
            return CGPath(rect: bounds, transform: nil)
        case "flag":
            return flagPath(bounds)
        case "bow-tie-rectangle":
            return bowTiePath(bounds)
        case "horizontal-cylinder":
            let rx = tokens.cylinderEllipseRadius
            let bodyRect = CGRect(x: bounds.minX + rx, y: bounds.minY, width: bounds.width - 2 * rx, height: bounds.height)
            return CGPath(rect: bodyRect, transform: nil)
        case "lined-cylinder", "data-store":
            let ry = tokens.cylinderEllipseRadius
            let bodyRect = CGRect(x: bounds.minX, y: bounds.minY + ry, width: bounds.width, height: bounds.height - 2 * ry)
            return CGPath(rect: bodyRect, transform: nil)
        case "flipped-triangle", "sloped-rectangle":
            return CGPath(rect: bounds, transform: nil)
        case "lined-rectangle":
            return CGPath(rect: bounds, transform: nil)
        case "icon-square", "icon", "image-square":
            return CGPath(rect: bounds, transform: nil)
        case "icon-circle":
            return trueCirclePath(bounds)
        case "icon-rounded":
            return roundedRectPath(bounds, cornerRadius: 6)
        default:
            return CGPath(rect: bounds, transform: nil)
        }
    }

    // MARK: - Shape Paths

    private func roundedRectPath(_ bounds: CGRect, cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addRoundedRect(in: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        return path
    }

    private func trueCirclePath(_ bounds: CGRect) -> CGPath {
        let cx = bounds.midX, cy = bounds.midY
        let r = min(bounds.width, bounds.height) / 2 - 2
        return CGPath(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2), transform: nil)
    }

    private func diamondPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let c = bounds.center
        path.move(to: CGPoint(x: c.x, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: c.y))
        path.addLine(to: CGPoint(x: c.x, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: c.y))
        path.closeSubpath()
        return path
    }

    private func hexagonPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let inset = bounds.height / 4
        let c = bounds.center
        path.move(to: CGPoint(x: bounds.minX + inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: c.y))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + inset, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: c.y))
        path.closeSubpath()
        return path
    }

    private func parallelogramPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let skew = bounds.width * 0.2
        path.move(to: CGPoint(x: bounds.minX + skew, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - skew, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.closeSubpath()
        return path
    }

    private func parallelogramAltPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let skew = bounds.width * 0.2
        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - skew, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + skew, y: bounds.maxY))
        path.closeSubpath()
        return path
    }

    private func trapezoidPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let inset = bounds.width * 0.15
        path.move(to: CGPoint(x: bounds.minX + inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.closeSubpath()
        return path
    }

    private func trapezoidAltPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let inset = bounds.width * 0.15
        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + inset, y: bounds.maxY))
        path.closeSubpath()
        return path
    }

    private func asymmetricPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let indent = tokens.asymmetricIndent
        let c = bounds.center
        path.move(to: CGPoint(x: bounds.minX + indent, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + indent, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: c.y))
        path.closeSubpath()
        return path
    }

    private func trianglePath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.closeSubpath()
        return path
    }

    private func cloudPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let w = bounds.width, h = bounds.height
        let r = min(w, h) * 0.12
        let midX = bounds.midX, midY = bounds.midY
        path.move(to: CGPoint(x: midX, y: bounds.minY + r * 0.5))
        path.addCurve(to: CGPoint(x: bounds.maxX - r, y: bounds.minY + r),
                      control1: CGPoint(x: midX + r * 2, y: bounds.minY - r * 0.3),
                      control2: CGPoint(x: bounds.maxX, y: bounds.minY - r * 0.2))
        path.addCurve(to: CGPoint(x: bounds.maxX - r * 0.5, y: midY),
                      control1: CGPoint(x: bounds.maxX + r, y: bounds.minY + r * 2),
                      control2: CGPoint(x: bounds.maxX + r, y: midY - r))
        path.addCurve(to: CGPoint(x: bounds.maxX - r, y: bounds.maxY - r),
                      control1: CGPoint(x: bounds.maxX + r, y: midY + r),
                      control2: CGPoint(x: bounds.maxX + r, y: bounds.maxY - r))
        path.addCurve(to: CGPoint(x: midX, y: bounds.maxY),
                      control1: CGPoint(x: bounds.maxX - r * 2, y: bounds.maxY + r * 0.3),
                      control2: CGPoint(x: midX + r * 2, y: bounds.maxY + r * 0.5))
        path.addCurve(to: CGPoint(x: bounds.minX + r, y: bounds.maxY - r),
                      control1: CGPoint(x: midX - r * 2, y: bounds.maxY + r * 0.5),
                      control2: CGPoint(x: bounds.minX, y: bounds.maxY + r * 0.3))
        path.addCurve(to: CGPoint(x: bounds.minX + r * 0.5, y: midY),
                      control1: CGPoint(x: bounds.minX - r, y: bounds.maxY - r * 2),
                      control2: CGPoint(x: bounds.minX - r, y: midY + r))
        path.addCurve(to: CGPoint(x: bounds.minX + r, y: bounds.minY + r),
                      control1: CGPoint(x: bounds.minX - r, y: midY - r),
                      control2: CGPoint(x: bounds.minX - r, y: bounds.minY + r))
        path.addCurve(to: CGPoint(x: midX, y: bounds.minY + r * 0.5),
                      control1: CGPoint(x: bounds.minX + r * 2, y: bounds.minY - r * 0.3),
                      control2: CGPoint(x: midX - r, y: bounds.minY - r))
        path.closeSubpath()
        return path
    }

    private func documentPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let w = bounds.width, h = bounds.height
        let waveDepth = h * 0.15
        let waveSegments = 5
        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY - waveDepth))
        let segWidth = w / CGFloat(waveSegments)
        for i in 0..<waveSegments {
            let sx = bounds.maxX - CGFloat(i) * segWidth
            let ex = bounds.maxX - CGFloat(i + 1) * segWidth
            let dir = i % 2 == 0 ? 1.0 : -1.0
            path.addCurve(to: CGPoint(x: ex, y: bounds.maxY - waveDepth),
                          control1: CGPoint(x: sx - segWidth * 0.25, y: bounds.maxY + waveDepth * dir),
                          control2: CGPoint(x: ex + segWidth * 0.25, y: bounds.maxY - waveDepth * 1.5))
        }
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY - waveDepth))
        path.closeSubpath()
        return path
    }

    private func delayPath(_ bounds: CGRect) -> CGPath {
        let w = bounds.width, h = bounds.height
        let r = h / 2
        return roundedRectPath(
            CGRect(x: bounds.minX, y: bounds.minY, width: w + r, height: h),
            cornerRadius: r
        )
    }

    private func hourglassPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let w = bounds.width
        let midX = bounds.midX, midY = bounds.midY
        let pinch = w * 0.15
        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: midX + pinch, y: midY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: midX - pinch, y: midY))
        path.closeSubpath()
        return path
    }

    private func lightningBoltPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let w = bounds.width, h = bounds.height
        path.move(to: CGPoint(x: bounds.minX + w * 0.4, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.minX + w * 0.25, y: bounds.midY - h * 0.1))
        path.addLine(to: CGPoint(x: bounds.minX + w * 0.55, y: bounds.midY - h * 0.1))
        path.addLine(to: CGPoint(x: bounds.minX + w * 0.35, y: bounds.midY + h * 0.1))
        path.addLine(to: CGPoint(x: bounds.minX + w * 0.75, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + w * 0.5, y: bounds.midY + h * 0.1))
        path.addLine(to: CGPoint(x: bounds.minX + w * 0.2, y: bounds.midY + h * 0.1))
        path.closeSubpath()
        return path
    }

    private func flagPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let w = bounds.width
        let inset = w * 0.15
        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.closeSubpath()
        return path
    }

    private func bowTiePath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let m = bounds.center
        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        path.addLine(to: CGPoint(x: m.x, y: m.y))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: m.x, y: m.y))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: m.x, y: m.y))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.closeSubpath()
        return path
    }

    private func curvedTrapezoidPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let inset = bounds.width * 0.15
        let cpOffset = bounds.height * 0.2
        path.move(to: CGPoint(x: bounds.minX + inset, y: bounds.minY))
        path.addCurve(to: CGPoint(x: bounds.maxX, y: bounds.maxY),
                      control1: CGPoint(x: bounds.maxX - inset, y: bounds.minY),
                      control2: CGPoint(x: bounds.maxX, y: bounds.maxY - cpOffset))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.addCurve(to: CGPoint(x: bounds.minX + inset, y: bounds.minY),
                      control1: CGPoint(x: bounds.minX, y: bounds.maxY - cpOffset),
                      control2: CGPoint(x: bounds.minX + inset + cpOffset, y: bounds.minY + cpOffset))
        path.closeSubpath()
        return path
    }

    private func notchedRectPath(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let n: CGFloat = 10
        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - n, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY + n))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.closeSubpath()
        return path
    }

    // MARK: - Spec-driven decoration rendering

    /// Draws decorations declared in the shape's `ShapeSpec`.
    ///
    /// Each decoration computes its own sub-bounds via `decoration.bounds`
    /// so that position-dependent details (cylinder caps, offset copies,
    /// inset panes, corner tags) can coexist with same-bounds polylines
    /// and ellipses in a single loop.
    private func _drawSpecDecorations(_ shape: String, in fullBounds: CGRect, context: CGContext, theme: DiagramTheme, inlineStyles: [String: String]) {
        guard let spec = ShapeSpecRegistry.spec(for: shape), !spec.decorations.isEmpty else { return }

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
