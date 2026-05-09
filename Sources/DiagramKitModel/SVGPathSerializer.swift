import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - SVG Path Serializer

/// Converts platform-independent `ShapePath` and `PathCommand` values
/// into SVG path-data attribute strings. Used by SVG renderers to consume
/// `ShapeSpecRegistry` and `EdgePathBuilder` outputs.
public enum SVGPathSerializer {

    // MARK: - ShapePath → SVG path-data

    /// Serialize a `ShapePath` into an SVG `d=""` attribute value.
    /// The path is positioned within the given bounding rectangle.
    /// Returns an SVG-compatible path-data string, or `nil` if the shape
    /// requires special SVG handling (e.g., state-start fills).
    public static func serialize(_ shapePath: ShapePath, in bounds: CGRect) -> String {
        switch shapePath {
        case .rect(let cornerRadius):
            if cornerRadius > 0 {
                return "M \(bounds.minX + cornerRadius) \(bounds.minY) L \(bounds.maxX - cornerRadius) \(bounds.minY) Q \(bounds.maxX) \(bounds.minY) \(bounds.maxX) \(bounds.minY + cornerRadius) L \(bounds.maxX) \(bounds.maxY - cornerRadius) Q \(bounds.maxX) \(bounds.maxY) \(bounds.maxX - cornerRadius) \(bounds.maxY) L \(bounds.minX + cornerRadius) \(bounds.maxY) Q \(bounds.minX) \(bounds.maxY) \(bounds.minX) \(bounds.maxY - cornerRadius) L \(bounds.minX) \(bounds.minY + cornerRadius) Q \(bounds.minX) \(bounds.minY) \(bounds.minX + cornerRadius) \(bounds.minY) Z"
            }
            return "M \(bounds.minX) \(bounds.minY) L \(bounds.maxX) \(bounds.minY) L \(bounds.maxX) \(bounds.maxY) L \(bounds.minX) \(bounds.maxY) Z"

        case .ellipse:
            let rx = bounds.width / 2
            let ry = bounds.height / 2
            return "M \(bounds.midX - rx) \(bounds.midY) A \(rx) \(ry) 0 1 1 \(bounds.midX + rx) \(bounds.midY) A \(rx) \(ry) 0 1 1 \(bounds.midX - rx) \(bounds.midY) Z"

        case .diamond:
            return "M \(bounds.midX) \(bounds.minY) L \(bounds.maxX) \(bounds.midY) L \(bounds.midX) \(bounds.maxY) L \(bounds.minX) \(bounds.midY) Z"

        case .hexagon:
            let inset = bounds.height / 4
            return "M \(bounds.minX + inset) \(bounds.minY) L \(bounds.maxX - inset) \(bounds.minY) L \(bounds.maxX) \(bounds.midY) L \(bounds.maxX - inset) \(bounds.maxY) L \(bounds.minX + inset) \(bounds.maxY) L \(bounds.minX) \(bounds.midY) Z"

        case .cylinder:
            // Body rectangle only; caps drawn separately in SVG
            return "M \(bounds.minX) \(bounds.minY) L \(bounds.maxX) \(bounds.minY) L \(bounds.maxX) \(bounds.maxY) L \(bounds.minX) \(bounds.maxY) Z"

        case .trapezoid(let skew):
            let inset = bounds.width * skew
            return "M \(bounds.minX + inset) \(bounds.minY) L \(bounds.maxX - inset) \(bounds.minY) L \(bounds.maxX) \(bounds.maxY) L \(bounds.minX) \(bounds.maxY) Z"

        case .parallelogram(let skew):
            let inset = bounds.width * skew
            return "M \(bounds.minX + inset) \(bounds.minY) L \(bounds.maxX) \(bounds.minY) L \(bounds.maxX - inset) \(bounds.maxY) L \(bounds.minX) \(bounds.maxY) Z"

        case .stadium:
            let r = bounds.height / 2
            return "M \(bounds.minX + r) \(bounds.minY) L \(bounds.maxX - r) \(bounds.minY) A \(r) \(r) 0 0 1 \(bounds.maxX) \(bounds.minY + r) L \(bounds.maxX) \(bounds.maxY - r) A \(r) \(r) 0 0 1 \(bounds.maxX - r) \(bounds.maxY) L \(bounds.minX + r) \(bounds.maxY) A \(r) \(r) 0 0 1 \(bounds.minX) \(bounds.maxY - r) L \(bounds.minX) \(bounds.minY + r) A \(r) \(r) 0 0 1 \(bounds.minX + r) \(bounds.minY) Z"

        case .subroutine, .asymmetric, .crossedCircle, .hourglass,
             .lightningBolt, .cloud, .bowTie, .triangle, .flag, .document,
             .polygon, .doubleCircle:
            // Complex shapes: return a recognizable rect as fallback
            return "M \(bounds.minX) \(bounds.minY) L \(bounds.maxX) \(bounds.minY) L \(bounds.maxX) \(bounds.maxY) L \(bounds.minX) \(bounds.maxY) Z"
        }
    }

    // MARK: - PathCommand → SVG path-data

    /// Serialize a sequence of `PathCommand` values into an SVG `d=""` string.
    public static func serialize(_ commands: [PathCommand]) -> String {
        var parts: [String] = []
        for command in commands {
            switch command {
            case .move(let to):
                parts.append("M \(_fmt(to.x)) \(_fmt(to.y))")
            case .line(let to):
                parts.append("L \(_fmt(to.x)) \(_fmt(to.y))")
            case .cubicCurve(let to, let c1, let c2):
                parts.append("C \(_fmt(c1.x)) \(_fmt(c1.y)), \(_fmt(c2.x)) \(_fmt(c2.y)), \(_fmt(to.x)) \(_fmt(to.y))")
            case .quadCurve(let to, let control):
                parts.append("Q \(_fmt(control.x)) \(_fmt(control.y)), \(_fmt(to.x)) \(_fmt(to.y))")
            case .close:
                parts.append("Z")
            }
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Private

    private static func _fmt(_ value: CGFloat) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded(.down) {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.2f", rounded)
    }
}
