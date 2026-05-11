// Apple-only — depends on gated symbols (ShapePath/BMFont/etc.). Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
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

        case .subroutine:
            // Outer rectangle only; inner vertical lines are decorations
            // and drawn separately by the renderer.
            return "M \(_fmt(bounds.minX)) \(_fmt(bounds.minY)) L \(_fmt(bounds.maxX)) \(_fmt(bounds.minY)) L \(_fmt(bounds.maxX)) \(_fmt(bounds.maxY)) L \(_fmt(bounds.minX)) \(_fmt(bounds.maxY)) Z"

        case .asymmetric(let indent):
            // Rect with a triangular notch carved into the left edge.
            return "M \(_fmt(bounds.minX + indent)) \(_fmt(bounds.minY)) L \(_fmt(bounds.maxX)) \(_fmt(bounds.minY)) L \(_fmt(bounds.maxX)) \(_fmt(bounds.maxY)) L \(_fmt(bounds.minX + indent)) \(_fmt(bounds.maxY)) L \(_fmt(bounds.minX)) \(_fmt(bounds.midY)) Z"

        case .crossedCircle:
            // Outer circle (cross strokes are decorations).
            let rx = bounds.width / 2
            let ry = bounds.height / 2
            return "M \(_fmt(bounds.midX - rx)) \(_fmt(bounds.midY)) A \(_fmt(rx)) \(_fmt(ry)) 0 1 1 \(_fmt(bounds.midX + rx)) \(_fmt(bounds.midY)) A \(_fmt(rx)) \(_fmt(ry)) 0 1 1 \(_fmt(bounds.midX - rx)) \(_fmt(bounds.midY)) Z"

        case .hourglass:
            // Two triangles meeting at center (pinched mid-line).
            let pinch = bounds.width * 0.15
            return "M \(_fmt(bounds.minX)) \(_fmt(bounds.minY)) L \(_fmt(bounds.maxX)) \(_fmt(bounds.minY)) L \(_fmt(bounds.midX + pinch)) \(_fmt(bounds.midY)) L \(_fmt(bounds.maxX)) \(_fmt(bounds.maxY)) L \(_fmt(bounds.minX)) \(_fmt(bounds.maxY)) L \(_fmt(bounds.midX - pinch)) \(_fmt(bounds.midY)) Z"

        case .lightningBolt:
            // Zig-zag bolt — coordinates mirror `ShapeRenderer.lightningBoltPath`.
            let w = bounds.width
            let h = bounds.height
            return "M \(_fmt(bounds.minX + w * 0.4)) \(_fmt(bounds.minY))"
                + " L \(_fmt(bounds.minX + w * 0.25)) \(_fmt(bounds.midY - h * 0.1))"
                + " L \(_fmt(bounds.minX + w * 0.55)) \(_fmt(bounds.midY - h * 0.1))"
                + " L \(_fmt(bounds.minX + w * 0.35)) \(_fmt(bounds.midY + h * 0.1))"
                + " L \(_fmt(bounds.minX + w * 0.75)) \(_fmt(bounds.maxY))"
                + " L \(_fmt(bounds.minX + w * 0.5)) \(_fmt(bounds.midY + h * 0.1))"
                + " L \(_fmt(bounds.minX + w * 0.2)) \(_fmt(bounds.midY + h * 0.1)) Z"

        case .cloud:
            // Eight cubic curve segments — mirrors `ShapeRenderer.cloudPath`.
            let w = bounds.width
            let h = bounds.height
            let r = Swift.min(w, h) * 0.12
            let midX = bounds.midX
            let midY = bounds.midY
            var parts: [String] = []
            parts.append("M \(_fmt(midX)) \(_fmt(bounds.minY + r * 0.5))")
            parts.append("C \(_fmt(midX + r * 2)) \(_fmt(bounds.minY - r * 0.3)), \(_fmt(bounds.maxX)) \(_fmt(bounds.minY - r * 0.2)), \(_fmt(bounds.maxX - r)) \(_fmt(bounds.minY + r))")
            parts.append("C \(_fmt(bounds.maxX + r)) \(_fmt(bounds.minY + r * 2)), \(_fmt(bounds.maxX + r)) \(_fmt(midY - r)), \(_fmt(bounds.maxX - r * 0.5)) \(_fmt(midY))")
            parts.append("C \(_fmt(bounds.maxX + r)) \(_fmt(midY + r)), \(_fmt(bounds.maxX + r)) \(_fmt(bounds.maxY - r)), \(_fmt(bounds.maxX - r)) \(_fmt(bounds.maxY - r))")
            parts.append("C \(_fmt(bounds.maxX - r * 2)) \(_fmt(bounds.maxY + r * 0.3)), \(_fmt(midX + r * 2)) \(_fmt(bounds.maxY + r * 0.5)), \(_fmt(midX)) \(_fmt(bounds.maxY))")
            parts.append("C \(_fmt(midX - r * 2)) \(_fmt(bounds.maxY + r * 0.5)), \(_fmt(bounds.minX)) \(_fmt(bounds.maxY + r * 0.3)), \(_fmt(bounds.minX + r)) \(_fmt(bounds.maxY - r))")
            parts.append("C \(_fmt(bounds.minX - r)) \(_fmt(bounds.maxY - r * 2)), \(_fmt(bounds.minX - r)) \(_fmt(midY + r)), \(_fmt(bounds.minX + r * 0.5)) \(_fmt(midY))")
            parts.append("C \(_fmt(bounds.minX - r)) \(_fmt(midY - r)), \(_fmt(bounds.minX - r)) \(_fmt(bounds.minY + r)), \(_fmt(bounds.minX + r)) \(_fmt(bounds.minY + r))")
            parts.append("C \(_fmt(bounds.minX + r * 2)) \(_fmt(bounds.minY - r * 0.3)), \(_fmt(midX - r)) \(_fmt(bounds.minY - r)), \(_fmt(midX)) \(_fmt(bounds.minY + r * 0.5))")
            parts.append("Z")
            return parts.joined(separator: " ")

        case .bowTie:
            // Two triangles meeting at center, hourglass-style on the
            // horizontal axis. Mirrors `ShapeRenderer.bowTiePath`.
            let m = CGPoint(x: bounds.midX, y: bounds.midY)
            return "M \(_fmt(bounds.minX)) \(_fmt(bounds.minY))"
                + " L \(_fmt(m.x)) \(_fmt(m.y))"
                + " L \(_fmt(bounds.maxX)) \(_fmt(bounds.minY))"
                + " L \(_fmt(m.x)) \(_fmt(m.y))"
                + " L \(_fmt(bounds.maxX)) \(_fmt(bounds.maxY))"
                + " L \(_fmt(m.x)) \(_fmt(m.y))"
                + " L \(_fmt(bounds.minX)) \(_fmt(bounds.maxY)) Z"

        case .triangle:
            return "M \(_fmt(bounds.midX)) \(_fmt(bounds.minY)) L \(_fmt(bounds.maxX)) \(_fmt(bounds.maxY)) L \(_fmt(bounds.minX)) \(_fmt(bounds.maxY)) Z"

        case .flag:
            // Paper-tape / flag — rectangle with a chevron cut into the right edge.
            let inset = bounds.width * 0.15
            return "M \(_fmt(bounds.minX)) \(_fmt(bounds.minY))"
                + " L \(_fmt(bounds.maxX - inset)) \(_fmt(bounds.minY))"
                + " L \(_fmt(bounds.maxX)) \(_fmt(bounds.midY))"
                + " L \(_fmt(bounds.maxX - inset)) \(_fmt(bounds.maxY))"
                + " L \(_fmt(bounds.minX)) \(_fmt(bounds.maxY)) Z"

        case .document:
            // Rectangle with wavy bottom edge. Mirrors `ShapeRenderer.documentPath`.
            let w = bounds.width
            let h = bounds.height
            let waveDepth = h * 0.15
            let waveSegments = 5
            let segWidth = w / CGFloat(waveSegments)
            var parts: [String] = []
            parts.append("M \(_fmt(bounds.minX)) \(_fmt(bounds.minY))")
            parts.append("L \(_fmt(bounds.maxX)) \(_fmt(bounds.minY))")
            parts.append("L \(_fmt(bounds.maxX)) \(_fmt(bounds.maxY - waveDepth))")
            for i in 0..<waveSegments {
                let sx = bounds.maxX - CGFloat(i) * segWidth
                let ex = bounds.maxX - CGFloat(i + 1) * segWidth
                let dir: CGFloat = i % 2 == 0 ? 1 : -1
                let c1x = sx - segWidth * 0.25
                let c1y = bounds.maxY + waveDepth * dir
                let c2x = ex + segWidth * 0.25
                let c2y = bounds.maxY - waveDepth * 1.5
                parts.append("C \(_fmt(c1x)) \(_fmt(c1y)), \(_fmt(c2x)) \(_fmt(c2y)), \(_fmt(ex)) \(_fmt(bounds.maxY - waveDepth))")
            }
            parts.append("L \(_fmt(bounds.minX)) \(_fmt(bounds.maxY - waveDepth))")
            parts.append("Z")
            return parts.joined(separator: " ")

        case .polygon(let vertices):
            guard let first = vertices.first else { return "" }
            var parts: [String] = []
            parts.append("M \(_fmt(first.x)) \(_fmt(first.y))")
            for vertex in vertices.dropFirst() {
                parts.append("L \(_fmt(vertex.x)) \(_fmt(vertex.y))")
            }
            parts.append("Z")
            return parts.joined(separator: " ")

        case .doubleCircle:
            // Outer ellipse only; the inner ellipse is drawn as a decoration
            // by the renderer (using the `gap` parameter).
            let rx = bounds.width / 2
            let ry = bounds.height / 2
            return "M \(_fmt(bounds.midX - rx)) \(_fmt(bounds.midY)) A \(_fmt(rx)) \(_fmt(ry)) 0 1 1 \(_fmt(bounds.midX + rx)) \(_fmt(bounds.midY)) A \(_fmt(rx)) \(_fmt(ry)) 0 1 1 \(_fmt(bounds.midX - rx)) \(_fmt(bounds.midY)) Z"

        case .notchedRectangle(let notchSize):
            // Rect with triangular notch carved into the top-right corner.
            return "M \(_fmt(bounds.minX)) \(_fmt(bounds.minY))"
                + " L \(_fmt(bounds.maxX - notchSize)) \(_fmt(bounds.minY))"
                + " L \(_fmt(bounds.maxX)) \(_fmt(bounds.minY + notchSize))"
                + " L \(_fmt(bounds.maxX)) \(_fmt(bounds.maxY))"
                + " L \(_fmt(bounds.minX)) \(_fmt(bounds.maxY)) Z"

        case .horizontalCylinder(let leftCapInset):
            // Body rectangle only; cap ellipses drawn separately.
            let minX = bounds.minX + leftCapInset
            let maxX = bounds.maxX - leftCapInset
            return "M \(_fmt(minX)) \(_fmt(bounds.minY))"
                + " L \(_fmt(maxX)) \(_fmt(bounds.minY))"
                + " L \(_fmt(maxX)) \(_fmt(bounds.maxY))"
                + " L \(_fmt(minX)) \(_fmt(bounds.maxY)) Z"

        case .trapezoidAlt(let skew):
            // Wide top, narrow bottom (mirror of `.trapezoid`).
            let inset = bounds.width * skew
            return "M \(_fmt(bounds.minX)) \(_fmt(bounds.minY))"
                + " L \(_fmt(bounds.maxX)) \(_fmt(bounds.minY))"
                + " L \(_fmt(bounds.maxX - inset)) \(_fmt(bounds.maxY))"
                + " L \(_fmt(bounds.minX + inset)) \(_fmt(bounds.maxY)) Z"

        case .parallelogramAlt(let skew):
            let inset = bounds.width * skew
            return "M \(_fmt(bounds.minX)) \(_fmt(bounds.minY))"
                + " L \(_fmt(bounds.maxX - inset)) \(_fmt(bounds.minY))"
                + " L \(_fmt(bounds.maxX)) \(_fmt(bounds.maxY))"
                + " L \(_fmt(bounds.minX + inset)) \(_fmt(bounds.maxY)) Z"

        case .triangleDown:
            return "M \(_fmt(bounds.minX)) \(_fmt(bounds.minY))"
                + " L \(_fmt(bounds.maxX)) \(_fmt(bounds.minY))"
                + " L \(_fmt(bounds.midX)) \(_fmt(bounds.maxY)) Z"

        case .slopedRectangle(let slope):
            let dy = bounds.height * slope
            return "M \(_fmt(bounds.minX)) \(_fmt(bounds.minY + dy))"
                + " L \(_fmt(bounds.maxX)) \(_fmt(bounds.minY))"
                + " L \(_fmt(bounds.maxX)) \(_fmt(bounds.maxY))"
                + " L \(_fmt(bounds.minX)) \(_fmt(bounds.maxY)) Z"

        case .polyline(let points):
            guard let first = points.first else { return "" }
            var parts: [String] = []
            parts.append("M \(_fmt(first.x)) \(_fmt(first.y))")
            for p in points.dropFirst() {
                parts.append("L \(_fmt(p.x)) \(_fmt(p.y))")
            }
            // Intentionally NOT closed — polyline is stroke-only
            return parts.joined(separator: " ")

        case .curvedTrapezoid(let skew):
            // Curved trapezoid — right edge curves inward like a display.
            // Mirrors `ShapeRenderer.curvedTrapezoidPath` and `_renderCurvedTrapezoid`.
            let inset = bounds.width * skew
            let cp = bounds.height * 0.2
            return "M \(_fmt(bounds.minX + inset)) \(_fmt(bounds.minY))"
                + " Q \(_fmt(bounds.maxX - inset)) \(_fmt(bounds.minY))"
                + " \(_fmt(bounds.maxX)) \(_fmt(bounds.maxY - cp))"
                + " L \(_fmt(bounds.maxX)) \(_fmt(bounds.maxY))"
                + " L \(_fmt(bounds.minX)) \(_fmt(bounds.maxY))"
                + " Q \(_fmt(bounds.minX)) \(_fmt(bounds.maxY - cp))"
                + " \(_fmt(bounds.minX + inset)) \(_fmt(bounds.minY)) Z"
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
#endif
