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

        if shape == "state-start" {
            let path = trueCirclePath(bounds)
            context.setFillColor(theme.foreground.cgColor)
            context.addPath(path)
            context.fillPath()
            context.restoreGState()
            return
        }

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

        if shape == "fork" || shape == "join" {
            context.setFillColor(theme.foreground.cgColor)
            context.addPath(roundedRectPath(bounds, cornerRadius: 2))
            context.fillPath()
            context.restoreGState()
            return
        }

        if shape == "rounded-with-title" {
            _drawRoundedWithTitle(bounds, context: context, theme: theme, inlineStyles: inlineStyles)
            context.restoreGState()
            return
        }

        if shape == "rect-with-title" {
            _drawRectWithTitle(bounds, context: context, theme: theme, inlineStyles: inlineStyles)
            context.restoreGState()
            return
        }

        let fillColor = theme.nodeFillColor(for: inlineStyles)
        let strokeColor = theme.nodeStrokeColor(for: inlineStyles)
        let path = shapePath(for: shape, in: bounds)

        context.setFillColor(fillColor.cgColor)
        context.addPath(path)
        context.fillPath()

        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(tokens.strokeWidthInnerBox)
        context.addPath(path)
        context.strokePath()

        _drawSpecDecorations(shape, in: bounds, context: context, theme: theme, inlineStyles: inlineStyles)
        drawShapeDetails(shape, in: bounds, context: context, theme: theme, inlineStyles: inlineStyles)

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

    // MARK: - Shape Details

    private func drawShapeDetails(_ shape: String, in bounds: CGRect, context: CGContext, theme: DiagramTheme, inlineStyles: [String: String]) {
        // Skip shapes whose same-bounds details are now rendered by
        // _drawSpecDecorations.  Position-dependent shapes (cylinder caps,
        // offset copies, inset panes, corner tags) still go through the
        // legacy switch below.
        if _isSpecDetailsCovered(shape) { return }

        switch shape {
        case "subroutine":
            let inset = tokens.subroutineInset
            context.setStrokeColor(theme.nodeStrokeColor(for: inlineStyles).cgColor)
            context.setLineWidth(tokens.strokeWidthInnerBox)
            context.move(to: CGPoint(x: bounds.minX + inset, y: bounds.minY))
            context.addLine(to: CGPoint(x: bounds.minX + inset, y: bounds.maxY))
            context.strokePath()
            context.move(to: CGPoint(x: bounds.maxX - inset, y: bounds.minY))
            context.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.maxY))
            context.strokePath()

        case "doublecircle":
            let innerBounds = bounds.insetBy(dx: tokens.doubleCircleGap, dy: tokens.doubleCircleGap)
            context.setStrokeColor(theme.nodeStrokeColor(for: inlineStyles).cgColor)
            context.setLineWidth(tokens.strokeWidthInnerBox)
            context.addPath(CGPath(ellipseIn: innerBounds, transform: nil))
            context.strokePath()

        case "cylinder":
            let ry = tokens.cylinderEllipseRadius
            let ellipseHeight = ry * 2
            let bodyTop = bounds.minY + ry
            let bodyBottom = bounds.maxY - ry

            let strokeColor = theme.nodeStrokeColor(for: inlineStyles)
            let fillColor = theme.nodeFillColor(for: inlineStyles)

            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(tokens.strokeWidthInnerBox)
            context.move(to: CGPoint(x: bounds.minX, y: bodyTop))
            context.addLine(to: CGPoint(x: bounds.minX, y: bodyBottom))
            context.strokePath()
            context.move(to: CGPoint(x: bounds.maxX, y: bodyTop))
            context.addLine(to: CGPoint(x: bounds.maxX, y: bodyBottom))
            context.strokePath()

            let bottomEllipse = CGRect(x: bounds.minX, y: bounds.maxY - ellipseHeight, width: bounds.width, height: ellipseHeight)
            let bottomPath = CGPath(ellipseIn: bottomEllipse, transform: nil)
            context.setFillColor(fillColor.cgColor)
            context.addPath(bottomPath)
            context.fillPath()
            context.setStrokeColor(strokeColor.cgColor)
            context.addPath(bottomPath)
            context.strokePath()

            let topEllipse = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: ellipseHeight)
            let topPath = CGPath(ellipseIn: topEllipse, transform: nil)
            context.setFillColor(fillColor.cgColor)
            context.addPath(topPath)
            context.fillPath()
            context.setStrokeColor(strokeColor.cgColor)
            context.addPath(topPath)
            context.strokePath()

        case "bang":
            // Center vertical line from top to bottom
            context.setStrokeColor(theme.nodeStrokeColor(for: inlineStyles).cgColor)
            context.setLineWidth(tokens.strokeWidthInnerBox)
            context.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
            context.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY))
            context.strokePath()

        case "framed-circle":
            let outerBounds = bounds.insetBy(dx: -4, dy: -4)
            context.setStrokeColor(theme.nodeStrokeColor(for: inlineStyles).cgColor)
            context.setLineWidth(tokens.strokeWidthInnerBox * 1.5)
            context.addPath(CGPath(ellipseIn: outerBounds, transform: nil))
            context.strokePath()

        case "crossed-circle":
            let cx = bounds.midX, cy = bounds.midY
            let r = min(bounds.width, bounds.height) / 2
            context.setStrokeColor(theme.nodeStrokeColor(for: inlineStyles).cgColor)
            context.setLineWidth(tokens.strokeWidthInnerBox)
            context.move(to: CGPoint(x: cx - r * 0.5, y: cy - r * 0.5))
            context.addLine(to: CGPoint(x: cx + r * 0.5, y: cy + r * 0.5))
            context.strokePath()
            context.move(to: CGPoint(x: cx + r * 0.5, y: cy - r * 0.5))
            context.addLine(to: CGPoint(x: cx - r * 0.5, y: cy + r * 0.5))
            context.strokePath()

        case "divided-rectangle":
            context.setStrokeColor(theme.nodeStrokeColor(for: inlineStyles).cgColor)
            context.setLineWidth(tokens.strokeWidthInnerBox)
            context.move(to: CGPoint(x: bounds.minX, y: bounds.midY))
            context.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
            context.strokePath()

        case "window-pane":
            let inset = bounds.width * 0.2
            let paneRect = CGRect(x: bounds.maxX - inset - 4, y: bounds.minY + 4,
                                  width: inset, height: bounds.height - 8)
            context.setStrokeColor(theme.nodeStrokeColor(for: inlineStyles).cgColor)
            context.setLineWidth(tokens.strokeWidthInnerBox)
            context.addPath(CGPath(rect: paneRect, transform: nil))
            context.strokePath()

        case "stacked-document":
            let offset: CGFloat = 4
            let backRect = bounds.offsetBy(dx: -offset, dy: -offset)
            context.saveGState()
            context.setStrokeColor(theme.nodeStrokeColor(for: inlineStyles).cgColor)
            context.setLineWidth(tokens.strokeWidthInnerBox)
            context.setAlpha(0.4)
            context.addPath(documentPath(backRect))
            context.strokePath()
            context.restoreGState()

        case "stacked-rectangle":
            let offset: CGFloat = 4
            let backRect = bounds.offsetBy(dx: -offset, dy: -offset)
            context.saveGState()
            context.setStrokeColor(theme.nodeStrokeColor(for: inlineStyles).cgColor)
            context.setLineWidth(tokens.strokeWidthInnerBox)
            context.setAlpha(0.4)
            context.addPath(CGPath(rect: backRect, transform: nil))
            context.strokePath()
            context.restoreGState()

        case "notched-rectangle":
            let notchSize: CGFloat = 10
            context.setFillColor(theme.nodeFillColor(for: inlineStyles).cgColor)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
            path.addLine(to: CGPoint(x: bounds.maxX - notchSize, y: bounds.minY))
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY + notchSize))
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
            path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()

        case "tagged-document", "tagged-rectangle":
            let notchSize: CGFloat = 10
            context.setStrokeColor(theme.nodeStrokeColor(for: inlineStyles).cgColor)
            context.setLineWidth(tokens.strokeWidthInnerBox)
            context.move(to: CGPoint(x: bounds.maxX - notchSize, y: bounds.minY))
            context.addLine(to: CGPoint(x: bounds.maxX - notchSize, y: bounds.minY + notchSize))
            context.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY + notchSize))
            context.strokePath()
            let tagPath = CGMutablePath()
            tagPath.move(to: CGPoint(x: bounds.maxX - notchSize, y: bounds.minY))
            tagPath.addLine(to: CGPoint(x: bounds.maxX - notchSize, y: bounds.minY + notchSize))
            tagPath.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY + notchSize))
            tagPath.closeSubpath()
            context.setFillColor(theme.nodeFillColor(for: inlineStyles).cgColor)
            context.addPath(tagPath)
            context.fillPath()

        default:
            break
        }
    }

    // MARK: - Spec-driven decoration rendering

    /// Returns `true` when the shape's detail geometry is fully covered by
    /// spec decorations — the legacy `drawShapeDetails` switch should be
    /// skipped to avoid double-stroking.
    ///
    /// Position-dependent shapes (window-pane, stacked-*, tagged-*) are
    /// excluded because their decorations need sub-bounds support that the
    /// current system doesn't provide yet.
    private func _isSpecDetailsCovered(_ shape: String) -> Bool {
        guard let spec = ShapeSpecRegistry.spec(for: shape),
              !spec.decorations.isEmpty else { return false }
        switch shape {
        case "window-pane", "stacked-document", "stacked-rectangle",
             "tagged-document", "tagged-rectangle":
            return false
        default:
            return true
        }
    }

    /// Draws decorations declared in the shape's `ShapeSpec`.
    ///
    /// Only handles same-bounds decorations (polyline strokes, centered
    /// ellipses, etc.). Position-dependent details (cylinder caps, offset
    /// copies, inset panes) remain in `drawShapeDetails` until the
    /// decoration system supports sub-bounds positioning.
    private func _drawSpecDecorations(_ shape: String, in bounds: CGRect, context: CGContext, theme: DiagramTheme, inlineStyles: [String: String]) {
        guard let spec = ShapeSpecRegistry.spec(for: shape), !spec.decorations.isEmpty else { return }

        let strokeColor = theme.nodeStrokeColor(for: inlineStyles)
        let fillColor = theme.nodeFillColor(for: inlineStyles)

        for decoration in spec.decorations {
            let decorationPath = decoration.path(bounds, config)
            let cgPath = CGPathRenderer.makePath(from: decorationPath, in: bounds, config: config)

            switch decoration.stroke {
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

            if decoration.fillsBackground {
                context.setFillColor(fillColor.cgColor)
                context.addPath(cgPath)
                context.fillPath()
            }
        }
    }

    private func _drawRoundedWithTitle(_ bounds: CGRect, context: CGContext, theme: DiagramTheme, inlineStyles: [String: String]) {
        let titleHeight: CGFloat = 35
        let fillColor = theme.nodeFillColor(for: inlineStyles)
        let strokeColor = theme.nodeStrokeColor(for: inlineStyles)
        let headerColor = theme.subgraphHeaderColor()

        let path = roundedRectPath(bounds, cornerRadius: 8)
        context.setFillColor(fillColor.cgColor)
        context.addPath(path)
        context.fillPath()

        context.setFillColor(headerColor.cgColor)
        context.addPath(roundedRectPath(CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: titleHeight), cornerRadius: 8))
        context.fillPath()

        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(tokens.strokeWidthInnerBox)
        context.addPath(path)
        context.strokePath()
    }

    private func _drawRectWithTitle(_ bounds: CGRect, context: CGContext, theme: DiagramTheme, inlineStyles: [String: String]) {
        let titleHeight: CGFloat = 24
        let fillColor = theme.nodeFillColor(for: inlineStyles)
        let strokeColor = theme.nodeStrokeColor(for: inlineStyles)
        let headerColor = theme.subgraphHeaderColor()

        let path = roundedRectPath(bounds, cornerRadius: 4)
        context.setFillColor(fillColor.cgColor)
        context.addPath(path)
        context.fillPath()

        let titleRect = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: titleHeight)
        let titlePath = CGMutablePath()
        titlePath.addRoundedRect(in: titleRect, cornerWidth: 4, cornerHeight: 4)
        context.setFillColor(headerColor.cgColor)
        context.addPath(titlePath)
        context.fillPath()

        let divY = bounds.minY + titleHeight
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(tokens.strokeWidthInnerBox)
        context.move(to: CGPoint(x: bounds.minX, y: divY))
        context.addLine(to: CGPoint(x: bounds.maxX, y: divY))
        context.strokePath()

        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(tokens.strokeWidthInnerBox)
        context.addPath(path)
        context.strokePath()
    }
}
#endif
