// Apple-only — depends on gated symbols (ShapePath/BMFont/etc.). Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Path Command

/// A single drawing command in a platform-independent edge path.
///
/// CG renderers convert these to `CGPath` operations; SVG renderers
/// serialize them to SVG path-data strings.
public enum PathCommand: Sendable {
    /// Move to absolute coordinates.
    case move(to: CGPoint)

    /// Line to absolute coordinates.
    case line(to: CGPoint)

    /// Cubic Bézier curve with two control points.
    case cubicCurve(to: CGPoint, control1: CGPoint, control2: CGPoint)

    /// Quadratic Bézier curve with one control point.
    case quadCurve(to: CGPoint, control: CGPoint)

    /// Close the current subpath.
    case close
}

// MARK: - Edge Path Builder

/// Builds platform-independent edge paths from point sequences.
///
/// Handles curve interpolation (basis, cardinal, linear, step) and
/// arrowhead geometry. CG and SVG renderers consume `PathCommand`
/// outputs so edge rendering stays consistent across pipelines.
public enum EdgePathBuilder {

    // MARK: - Curve Interpolation

    /// Convert a sequence of waypoints into drawing commands,
    /// applying the named curve interpolation if specified.
    ///
    /// - Parameters:
    ///   - points: The waypoint sequence (must have at least 2 points).
    ///   - curveType: One of `"basis"`, `"cardinal"`, `"linear"`, `"step"`,
    ///     `"stepBefore"`, `"stepAfter"`, or `nil` for straight lines.
    /// - Returns: A sequence of `PathCommand` values starting with `.move`.
    public static func commands(
        points: [CGPoint],
        curveType: String? = nil
    ) -> [PathCommand] {
        guard points.count >= 2 else { return [] }

        switch curveType?.lowercased() {
        case "step", "stepbefore":
            return stepCommands(points: points, after: false)
        case "stepafter":
            return stepCommands(points: points, after: true)
        case "basis":
            return basisCommands(points: points)
        case "cardinal":
            return cardinalCommands(points: points, tension: 0.5)
        case "linear", .none:
            return linearCommands(points: points)
        default:
            return linearCommands(points: points)
        }
    }

    // MARK: - Arrow Head Geometry

    /// Generate path commands for an arrowhead at the given tip position,
    /// pointing along the direction from `tail` to `tip`.
    ///
    /// - Parameters:
    ///   - style: The arrowhead style (`.arrow`, `.open`, `.circle`, `.cross`, `.diamond`).
    ///   - tip: The tip point of the arrowhead.
    ///   - tail: The point just before the tip (defines direction).
    ///   - size: The arrowhead size (width × height).
    /// - Returns: Platform-independent `ShapePath` for the arrowhead.
    public static func arrow(
        style: ArrowHeadStyle,
        tip: CGPoint,
        tail: CGPoint,
        size: CGSize
    ) -> ShapePath {
        let dx = tip.x - tail.x
        let dy = tip.y - tail.y
        let len = hypot(dx, dy)
        guard len > 0.001 else { return .rect(cornerRadius: 0) }

        let ux = dx / len
        let uy = dy / len
        let nx = -uy  // perpendicular (rotate 90° CCW)
        let ny = ux

        let hw = size.width / 2   // half the arrowhead width
        let hh = size.height      // total arrowhead length along direction

        switch style {
        case .none:
            return .rect(cornerRadius: 0)

        case .arrow:
            // Filled triangle: tip → base-left → base-right → close
            let baseX = tip.x - ux * hh
            let baseY = tip.y - uy * hh
            return .polygon(vertices: [
                tip,
                CGPoint(x: baseX + nx * hw, y: baseY + ny * hw),
                CGPoint(x: baseX - nx * hw, y: baseY - ny * hw),
            ])

        case .open:
            // Open triangle: two lines from tip to base corners
            let baseX = tip.x - ux * hh
            let baseY = tip.y - uy * hh
            return .polygon(vertices: [
                tip,
                CGPoint(x: baseX + nx * hw, y: baseY + ny * hw),
                CGPoint(x: baseX - nx * hw, y: baseY - ny * hw),
                tip,
            ])

        case .circle:
            // Circle centered at the tip; renderer centers ellipse in bounding box
            return .ellipse

        case .cross:
            // Cross (×) at the tip
            let cx = tip.x - ux * hh / 2
            let cy = tip.y - uy * hh / 2
            let s = hw * 0.7
            return .polygon(vertices: [
                CGPoint(x: cx - s, y: cy - s),
                CGPoint(x: cx + s, y: cy + s),
                CGPoint(x: cx, y: cy),
                CGPoint(x: cx - s, y: cy + s),
                CGPoint(x: cx + s, y: cy - s),
            ])

        case .diamond:
            // Diamond centered behind the tip
            let cx = tip.x - ux * hh / 2
            let cy = tip.y - uy * hh / 2
            return .polygon(vertices: [
                CGPoint(x: cx, y: cy - hh / 2),
                CGPoint(x: cx + hw, y: cy),
                CGPoint(x: cx, y: cy + hh / 2),
                CGPoint(x: cx - hw, y: cy),
            ])
        }
    }

    // MARK: - Private curve implementations

    private static func linearCommands(points: [CGPoint]) -> [PathCommand] {
        var result: [PathCommand] = [.move(to: points[0])]
        for i in 1..<points.count {
            result.append(.line(to: points[i]))
        }
        return result
    }

    private static func stepCommands(points: [CGPoint], after: Bool) -> [PathCommand] {
        var result: [PathCommand] = [.move(to: points[0])]
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            if after {
                result.append(.line(to: CGPoint(x: curr.x, y: prev.y)))
            } else {
                result.append(.line(to: CGPoint(x: prev.x, y: curr.y)))
            }
            result.append(.line(to: curr))
        }
        return result
    }

    /// B-spline (basis) interpolation through the waypoints.
    private static func basisCommands(points: [CGPoint]) -> [PathCommand] {
        let n = points.count
        guard n >= 2 else { return linearCommands(points: points) }

        // Compute B-spline control points using the standard basis matrix.
        // For each segment between p[i] and p[i+1], we compute two intermediate
        // control points from the Catmull-Rom basis with tension 0.
        var result: [PathCommand] = [.move(to: points[0])]

        for i in 0..<(n - 1) {
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(n - 1, i + 2)]

            let cp1x = p1.x + (p2.x - p0.x) / 6
            let cp1y = p1.y + (p2.y - p0.y) / 6
            let cp2x = p2.x - (p3.x - p1.x) / 6
            let cp2y = p2.y - (p3.y - p1.y) / 6

            result.append(.cubicCurve(
                to: p2,
                control1: CGPoint(x: cp1x, y: cp1y),
                control2: CGPoint(x: cp2x, y: cp2y)
            ))
        }

        return result
    }

    /// Cardinal spline (Catmull-Rom with adjustable tension) through the waypoints.
    /// `tension = 0` produces the standard Catmull-Rom spline.
    private static func cardinalCommands(points: [CGPoint], tension: CGFloat) -> [PathCommand] {
        let n = points.count
        guard n >= 2 else { return linearCommands(points: points) }

        let t = (1.0 - tension) / 2.0
        var result: [PathCommand] = [.move(to: points[0])]

        for i in 0..<(n - 1) {
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(n - 1, i + 2)]

            let cp1x = p1.x + t * (p2.x - p0.x)
            let cp1y = p1.y + t * (p2.y - p0.y)
            let cp2x = p2.x - t * (p3.x - p1.x)
            let cp2y = p2.y - t * (p3.y - p1.y)

            result.append(.cubicCurve(
                to: p2,
                control1: CGPoint(x: cp1x, y: cp1y),
                control2: CGPoint(x: cp2x, y: cp2y)
            ))
        }

        return result
    }
}

// MARK: - Arrow Head Style

/// Arrowhead styles matching `ArrowHeadType` in the Mermaid type system.
public enum ArrowHeadStyle: String, Sendable {
    case none
    case arrow
    case open
    case circle
    case cross
    case diamond
}
#endif
