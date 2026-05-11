// Per-diagram-family constants extracted from `RenderConfig.swift`.
// These are now owned by `RenderTokens` as the source of truth, with
// `RenderConfig` forwarding through `self.tokens.sequenceLoopH` etc.
// during the migration to the three-way `RenderConfig` split (A5).
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics

extension RenderTokens {

    // MARK: - Sequence Diagram Constants

    public var sequenceLoopH: CGFloat { 20 }
    public var sequenceTabHeight: CGFloat { 18 }
    public var sequenceFoldSize: CGFloat { 6 }
}
#endif
