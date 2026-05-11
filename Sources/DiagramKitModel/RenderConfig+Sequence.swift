// Per-diagram-family constants forwarded from `RenderTokens`.
// These are the migration seam for the A5 `RenderConfig` split.
// The authoritative values live in `RenderTokens+Sequence.swift`.
// Remove this file once all consumers use `RenderTokens` directly.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics

extension RenderConfig {

    // MARK: - Sequence Diagram Constants (forwarded)

    public var sequenceLoopH: CGFloat { tokens.sequenceLoopH }
    public var sequenceTabHeight: CGFloat { tokens.sequenceTabHeight }
    public var sequenceFoldSize: CGFloat { tokens.sequenceFoldSize }
}
#endif
