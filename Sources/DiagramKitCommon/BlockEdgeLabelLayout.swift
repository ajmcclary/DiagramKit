import Foundation

/// Layout helpers for block diagram edge labels. The CG and SVG renderers
/// previously open-coded slightly different text-baseline offsets (CG used
/// `+5`, SVG used `+3`), making the two outputs visually inconsistent.
/// Both now snap to the SVG value (`+3`) by routing through this helper.
public enum BlockEdgeLabelLayout {
    /// Y offset of the text baseline relative to the edge midpoint.
    public static let textBaselineOffset: Double = 3

    /// Height of the SVG background rect drawn behind the text.
    public static let backgroundHeight: Double = 20

    /// Y offset of the background rect's top edge relative to the edge midpoint.
    public static let backgroundTopOffset: Double = 12

    /// Corner radius of the SVG background rect.
    public static let backgroundCornerRadius: Double = BlockRenderConstants.edgeLabelCornerRadius

    /// Text baseline point (horizontally centered) for the edge midpoint.
    public static func textBaseline(at midpoint: DiagramPoint) -> DiagramPoint {
        DiagramPoint(x: midpoint.x, y: midpoint.y + textBaselineOffset)
    }

    /// SVG background rect drawn under the text, given the edge midpoint and
    /// the label's rendered width.
    public static func backgroundRect(at midpoint: DiagramPoint, labelWidth: Double) -> DiagramRect {
        DiagramRect(
            origin: DiagramPoint(x: midpoint.x - labelWidth / 2, y: midpoint.y - backgroundTopOffset),
            size: DiagramSize(width: labelWidth, height: backgroundHeight)
        )
    }

    /// Heuristic label-width estimator currently shared with the SVG path:
    /// `max(40, count * 8)`. The CG path doesn't draw a background and so
    /// doesn't need this; the heuristic is centralized here anyway so both
    /// renderers can adopt it later without redefining the formula.
    public static func labelWidth(for label: String) -> Double {
        max(40.0, Double(label.count) * 8.0)
    }
}
