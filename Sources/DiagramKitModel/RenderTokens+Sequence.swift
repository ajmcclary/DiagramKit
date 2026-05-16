// Per-diagram-family constants extracted from `RenderConfig.swift`.
// These are now owned by `RenderTokens` as the source of truth, with
// `RenderConfig` forwarding through `self.tokens.sequenceLoopH` etc.
// during the migration to the three-way `RenderConfig` split (A5).
//
// Values that both the SVG renderer (Linux-portable) and the CG
// renderer read are sourced from `SequenceRenderConstants` in
// `DiagramKitCommon` so the two paths can never drift.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics
import DiagramKitCommon

extension RenderTokens {

    // MARK: - Sequence Diagram Constants

    public var sequenceLoopH: CGFloat { CGFloat(SequenceRenderConstants.selfLoopHeight) }
    public var sequenceTabHeight: CGFloat { CGFloat(SequenceRenderConstants.blockTabHeight) }
    public var sequenceFoldSize: CGFloat { 6 }
}
#endif
