import Foundation

/// Shared rendering constants for the Block diagram family.
///
/// Both the SVG renderer (`Sources/DiagramKitModel/src_block_renderer.swift`,
/// Linux-portable) and the CG renderer (`Sources/DiagramKitRenderingCG/
/// DiagramRenderer+Block.swift`, Apple-only) read these values so a tweak
/// propagates to both paths. The Apple-only `RenderTokens` struct cannot be
/// referenced from the Linux-portable SVG renderer, so the canonical
/// numbers live here as plain `Double`s.
public enum BlockRenderConstants {
    /// Default node/edge stroke width in points. Matches the SVG
    /// `stroke-width="1.5"` literal used historically.
    public static let strokeWidth: Double = 1.5

    /// Stroke width for `thick` edge variants. Matches the SVG
    /// `stroke-width="3.5"` literal used historically.
    public static let thickStrokeWidth: Double = 3.5

    /// Corner radius for edge-label background rectangles. CG and SVG must
    /// agree; mirrors `RenderTokens.edgeLabelCornerRadius` (which lives in
    /// the Apple-only `DiagramKitModel` slice and is therefore unreachable
    /// from the Linux-portable SVG renderer).
    public static let edgeLabelCornerRadius: Double = 2
}
