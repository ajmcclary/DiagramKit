import Foundation

/// Layout constants and helpers for the block diagram's composite/cluster
/// nodes. Both the CG renderer (`DiagramRenderer+Block.swift`) and the SVG
/// renderer (`src_block_renderer.swift`) previously open-coded the 20pt
/// title-band height and the 12pt title-baseline offset; routing through
/// this helper keeps the two paths in lock-step.
public enum BlockClusterLayout {
    /// Height reserved at the top of the cluster bounds for the title.
    public static let titleBandHeight: Double = 20

    /// Y offset of the title baseline relative to the cluster's `minY`.
    public static let titleBaselineOffset: Double = 12

    /// Body rect (cluster background) within the full cluster bounds.
    public static func bodyRect(in bounds: DiagramRect) -> DiagramRect {
        DiagramRect(
            origin: DiagramPoint(x: bounds.x, y: bounds.y + titleBandHeight),
            size: DiagramSize(width: bounds.width, height: max(0, bounds.height - titleBandHeight))
        )
    }

    /// Title baseline point (horizontally centered) within the full cluster bounds.
    public static func titleBaseline(in bounds: DiagramRect) -> DiagramPoint {
        DiagramPoint(x: bounds.midX, y: bounds.y + titleBaselineOffset)
    }
}
