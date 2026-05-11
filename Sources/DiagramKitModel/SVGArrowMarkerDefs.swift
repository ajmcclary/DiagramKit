import Foundation
import DiagramKitCommon

// MARK: - SVG Arrow Marker Definitions

/// Shared SVG `<marker>` definitions used across diagram families.
///
/// The eight markers (arrowhead, circlehead, crosshead, diamondhead +
/// `-start` variants) are sized from `RenderTokens` so they stay
/// consistent with the `EdgePathBuilder.arrow()` geometry. Per-family
/// renderers that currently inline these can route through `common`
/// or `commonWithColor`.
public enum SVGArrowMarkerDefs: Sendable {
    /// Returns the standard set of eight arrow markers using
    /// `var(--_arrow)` for fill + stroke.
    public static func common() -> String {
        _markers(arrowStyle: arrowStyleVar)
    }

    /// Returns the standard set with a per-color override (for
    /// edges using `linkStyle stroke`). `suffix` is the
    /// escaped/URL-safe label appended to marker ids.
    public static func commonWithColor(_ color: String, suffix: String) -> String {
        let escaped = SVG.escapeAttribute(color)
        let style = "fill=\"\(escaped)\" stroke=\"\(escaped)\" stroke-width=\"0.75\" stroke-linejoin=\"round\""
        return _markers(arrowStyle: style, suffix: suffix)
    }

    /// Marker ids produced by `common()`.
    public static let markerIDs: Set<String> = [
        "arrowhead", "arrowhead-start",
        "circlehead", "circlehead-start",
        "crosshead", "crosshead-start",
        "diamondhead", "diamondhead-start",
    ]

    // MARK: - Private

    private static var arrowStyleVar: String {
        "fill=\"var(--_arrow)\" stroke=\"var(--_arrow)\" stroke-width=\"0.75\" stroke-linejoin=\"round\""
    }

    private static func _markers(arrowStyle: String, suffix: String = "") -> String {
        let w = original_src_styles.ARROW_HEAD.width
        let h = original_src_styles.ARROW_HEAD.height
        let refX = w - 1
        let cs: Double = h * 0.7
        let xs: Double = h * 0.6
        let suffixRef = suffix.isEmpty ? "" : "-\(suffix)"

        // Crosshead lines use stroke only (no fill), extracted from arrowStyle.
        let lineStroke: String = {
            // Match `stroke="..."` from the arrowStyle string.
            if let r = arrowStyle.range(of: #"stroke="([^"]*)""#, options: .regularExpression) {
                let val = arrowStyle[r].dropFirst(8).dropLast()
                return "stroke=\"\(val)\""
            }
            return "stroke=\"var(--_arrow)\""
        }()

        var parts: [String] = []
        // Arrow
        parts.append("  <marker id=\"arrowhead\(suffixRef)\" markerWidth=\"\(w)\" markerHeight=\"\(h)\" refX=\"\(refX)\" refY=\"\(h / 2)\" orient=\"auto\">")
        parts.append("    <polygon points=\"0 0, \(w) \(h / 2), 0 \(h)\" \(arrowStyle) />")
        parts.append("  </marker>")
        parts.append("  <marker id=\"arrowhead-start\(suffixRef)\" markerWidth=\"\(w)\" markerHeight=\"\(h)\" refX=\"1\" refY=\"\(h / 2)\" orient=\"auto-start-reverse\">")
        parts.append("    <polygon points=\"\(w) 0, 0 \(h / 2), \(w) \(h)\" \(arrowStyle) />")
        parts.append("  </marker>")
        // Circle
        parts.append("  <marker id=\"circlehead\(suffixRef)\" markerWidth=\"\(cs + 2)\" markerHeight=\"\(cs)\" refX=\"\(cs / 2 + 1)\" refY=\"\(cs / 2)\" orient=\"auto\">")
        parts.append("    <circle cx=\"\(cs / 2)\" cy=\"\(cs / 2)\" r=\"\(cs / 2 - 0.5)\" \(arrowStyle) />")
        parts.append("  </marker>")
        parts.append("  <marker id=\"circlehead-start\(suffixRef)\" markerWidth=\"\(cs + 2)\" markerHeight=\"\(cs)\" refX=\"\(cs / 2 - 1)\" refY=\"\(cs / 2)\" orient=\"auto-start-reverse\">")
        parts.append("    <circle cx=\"\(cs / 2)\" cy=\"\(cs / 2)\" r=\"\(cs / 2 - 0.5)\" \(arrowStyle) />")
        parts.append("  </marker>")
        // Cross
        parts.append("  <marker id=\"crosshead\(suffixRef)\" markerWidth=\"\(xs)\" markerHeight=\"\(xs)\" refX=\"\(xs / 2)\" refY=\"\(xs / 2)\" orient=\"auto\">")
        parts.append("    <line x1=\"0\" y1=\"0\" x2=\"\(xs)\" y2=\"\(xs)\" \(lineStroke) stroke-width=\"1.5\" />")
        parts.append("    <line x1=\"\(xs)\" y1=\"0\" x2=\"0\" y2=\"\(xs)\" \(lineStroke) stroke-width=\"1.5\" />")
        parts.append("  </marker>")
        parts.append("  <marker id=\"crosshead-start\(suffixRef)\" markerWidth=\"\(xs)\" markerHeight=\"\(xs)\" refX=\"\(xs / 2)\" refY=\"\(xs / 2)\" orient=\"auto-start-reverse\">")
        parts.append("    <line x1=\"0\" y1=\"0\" x2=\"\(xs)\" y2=\"\(xs)\" \(lineStroke) stroke-width=\"1.5\" />")
        parts.append("    <line x1=\"\(xs)\" y1=\"0\" x2=\"0\" y2=\"\(xs)\" \(lineStroke) stroke-width=\"1.5\" />")
        parts.append("  </marker>")
        // Diamond
        parts.append("  <marker id=\"diamondhead\(suffixRef)\" markerWidth=\"\(w * 1.2)\" markerHeight=\"\(h)\" refX=\"\(w)\" refY=\"\(h / 2)\" orient=\"auto\">")
        parts.append("    <polygon points=\"0 \(h / 2), \(w * 0.6) 0, \(w * 1.2) \(h / 2), \(w * 0.6) \(h)\" \(arrowStyle) />")
        parts.append("  </marker>")
        parts.append("  <marker id=\"diamondhead-start\(suffixRef)\" markerWidth=\"\(w * 1.2)\" markerHeight=\"\(h)\" refX=\"\(w * 0.2)\" refY=\"\(h / 2)\" orient=\"auto-start-reverse\">")
        parts.append("    <polygon points=\"\(w * 0.6) \(h / 2), 0 0, \(w * 1.2) \(h / 2), 0 \(h)\" \(arrowStyle) />")
        parts.append("  </marker>")
        return parts.joined(separator: "\n")
    }
}
