import Foundation
import CoreGraphics

// MARK: - CG Path Renderer

/// Converts platform-independent `ShapePath` and `PathCommand` values
/// into Core Graphics paths. Used by `NodeShapeRenderer` and `EdgeRenderer`
/// to consume `ShapeSpecRegistry` and `EdgePathBuilder` outputs.
public enum CGPathRenderer {

    // MARK: - ShapePath → CGPath

    /// Create a `CGPath` from a `ShapePath` description.
    /// The path is positioned within the given bounding rectangle.
    public static func makePath(from shapePath: ShapePath, in bounds: CGRect, config: RenderConfig) -> CGPath {
        switch shapePath {
        case .rect(let cornerRadius):
            return _roundedRect(bounds, radius: cornerRadius)

        case .ellipse:
            return CGPath(ellipseIn: bounds, transform: nil)

        case .diamond:
            return _diamond(bounds)

        case .hexagon:
            return _hexagon(bounds)

        case .cylinder(let topCapInset):
            return _cylinder(bounds, topCapInset: topCapInset)

        case .trapezoid(let skew):
            return _trapezoid(bounds, skew: skew)

        case .parallelogram(let skew):
            return _parallelogram(bounds, skew: skew)

        case .stadium:
            return _roundedRect(bounds, radius: bounds.height / 2)

        case .subroutine(let inset):
            return _subroutine(bounds, inset: inset)

        case .doubleCircle(let gap):
            return _doubleCircle(bounds, gap: gap)

        case .asymmetric(let indent):
            return _asymmetric(bounds, indent: indent)

        case .crossedCircle:
            return _trueCircle(bounds)

        case .hourglass:
            return _hourglass(bounds)

        case .lightningBolt:
            return _lightningBolt(bounds)

        case .cloud:
            return _cloud(bounds)

        case .bowTie(let indent):
            return _bowTie(bounds, indent: indent)

        case .triangle:
            return _triangle(bounds)

        case .flag:
            return _flag(bounds)

        case .document:
            return _document(bounds)

        case .polygon(let vertices):
            return _polygon(vertices, in: bounds)
        }
    }

    // MARK: - PathCommand → CGPath

    /// Build a `CGPath` from a sequence of `PathCommand` values.
    public static func makePath(from commands: [PathCommand]) -> CGPath {
        let path = CGMutablePath()
        for command in commands {
            switch command {
            case .move(let to):
                path.move(to: to)
            case .line(let to):
                path.addLine(to: to)
            case .cubicCurve(let to, let control1, let control2):
                path.addCurve(to: to, control1: control1, control2: control2)
            case .quadCurve(let to, let control):
                path.addQuadCurve(to: to, control: control)
            case .close:
                path.closeSubpath()
            }
        }
        return path
    }

    // MARK: - Private path builders

    private static func _roundedRect(_ bounds: CGRect, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addRoundedRect(in: bounds, cornerWidth: radius, cornerHeight: radius)
        return path
    }

    private static func _diamond(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        path.move(to: CGPoint(x: c.x, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: c.y))
        path.addLine(to: CGPoint(x: c.x, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: c.y))
        path.closeSubpath()
        return path
    }

    private static func _hexagon(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let inset = bounds.height / 4
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        path.move(to: CGPoint(x: bounds.minX + inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: c.y))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + inset, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: c.y))
        path.closeSubpath()
        return path
    }

    private static func _cylinder(_ bounds: CGRect, topCapInset: CGFloat) -> CGPath {
        // Return the body rectangle only; caps are drawn separately in details
        let bodyRect = CGRect(x: bounds.minX, y: bounds.minY + topCapInset,
                              width: bounds.width, height: bounds.height - 2 * topCapInset)
        return CGPath(rect: bodyRect, transform: nil)
    }

    private static func _trapezoid(_ bounds: CGRect, skew: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let inset = bounds.width * skew
        path.move(to: CGPoint(x: bounds.minX + inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.closeSubpath()
        return path
    }

    private static func _parallelogram(_ bounds: CGRect, skew: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let inset = bounds.width * skew
        path.move(to: CGPoint(x: bounds.minX + inset, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - inset, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.closeSubpath()
        return path
    }

    private static func _subroutine(_ bounds: CGRect, inset: CGFloat) -> CGPath {
        // Body is a rect; side lines are drawn in shape details
        return CGPath(rect: bounds, transform: nil)
    }

    private static func _doubleCircle(_ bounds: CGRect, gap: CGFloat) -> CGPath {
        // Outer circle; inner circle drawn in details
        return CGPath(ellipseIn: bounds, transform: nil)
    }

    private static func _asymmetric(_ bounds: CGRect, indent: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        path.move(to: CGPoint(x: bounds.minX + indent, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + indent, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: c.y))
        path.closeSubpath()
        return path
    }

    private static func _trueCircle(_ bounds: CGRect) -> CGPath {
        let cx = bounds.midX
        let cy = bounds.midY
        let r = min(bounds.width, bounds.height) / 2 - 2
        return CGPath(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2), transform: nil)
    }

    private static func _hourglass(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let w = bounds.width
        let pinch = w * 0.15
        path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.midX + pinch, y: bounds.midY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.midX - pinch, y: bounds.midY))
        path.closeSubpath()
        return path
    }

    private static func _lightningBolt(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let w = bounds.width
        let h = bounds.height
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

    private static func _cloud(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let w = bounds.width
        let h = bounds.height
        let r = min(w, h) * 0.12
        let midX = bounds.midX
        let midY = bounds.midY
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

    private static func _bowTie(_ bounds: CGRect, indent: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let m = CGPoint(x: bounds.midX, y: bounds.midY)
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

    private static func _triangle(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.closeSubpath()
        return path
    }

    private static func _flag(_ bounds: CGRect) -> CGPath {
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

    private static func _document(_ bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let w = bounds.width
        let h = bounds.height
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

    private static func _polygon(_ vertices: [CGPoint], in bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        guard let first = vertices.first else { return path }
        path.move(to: first)
        for v in vertices.dropFirst() {
            path.addLine(to: v)
        }
        path.closeSubpath()
        return path
    }
}
