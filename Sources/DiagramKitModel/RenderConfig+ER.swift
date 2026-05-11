// Per-diagram-family constants forwarded from `RenderTokens`.
// These are the migration seam for the A5 `RenderConfig` split.
// The authoritative values live in `RenderTokens+ER.swift`.
// Remove this file once all consumers use `RenderTokens` directly.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics

extension RenderConfig {

    // MARK: - ER Diagram Constants (forwarded)

    public var erPadding: CGFloat { tokens.erPadding }
    public var erBoxPadX: CGFloat { tokens.erBoxPadX }
    public var erHeaderHeight: CGFloat { tokens.erHeaderHeight }
    public var erRowHeight: CGFloat { tokens.erRowHeight }
    public var erMinWidth: CGFloat { tokens.erMinWidth }
    public var erAttrFontSize: CGFloat { tokens.erAttrFontSize }
}
#endif
