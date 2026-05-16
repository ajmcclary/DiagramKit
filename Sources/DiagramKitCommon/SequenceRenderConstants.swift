import Foundation

/// Shared rendering constants for the Sequence diagram family.
///
/// Both the SVG renderer (`Sources/DiagramKitModel/src_sequence_renderer.swift`,
/// Linux-portable) and the CG renderer (`Sources/DiagramKitRenderingCG/
/// DiagramRenderer+Sequence.swift`, Apple-only) read these values so a tweak
/// propagates to both paths. The Apple-only `RenderTokens` struct cannot be
/// referenced from the Linux-portable SVG renderer, so the canonical
/// numbers live here as plain `Double`s.
public enum SequenceRenderConstants {
    /// Horizontal extent of the self-loop's right edge measured from the
    /// participant's lifeline. The polyline traces a rectangle that opens
    /// toward the lifeline; this is its width.
    public static let selfLoopWidth: Double = 30

    /// Vertical extent of the self-loop's bottom edge measured from the
    /// arrow-head row. Mirrors `RenderTokens.sequenceLoopH` (Apple-only).
    public static let selfLoopHeight: Double = 20

    /// Horizontal gap between the right edge of the self-loop and the
    /// start of the message label.
    public static let selfLoopLabelGap: Double = 8

    /// Height of the rectangular tab that labels a sequence block
    /// (`loop`, `alt`, `opt`, `par`, `critical`, …). The CG and SVG
    /// renderers both draw this tab at the block's top-left corner and
    /// must agree on its height for the label to land in the same row.
    public static let blockTabHeight: Double = 18
}
