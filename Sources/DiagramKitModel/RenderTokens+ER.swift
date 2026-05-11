// Per-diagram-family constants extracted from `RenderConfig.swift`.
// These are now owned by `RenderTokens` as the source of truth, with
// `RenderConfig` forwarding during the migration to the three-way
// `RenderConfig` split (A5).
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics

extension RenderTokens {

    // MARK: - ER Diagram Constants

    public var erPadding: CGFloat { 40 }
    public var erBoxPadX: CGFloat { 14 }
    public var erHeaderHeight: CGFloat { 34 }
    public var erRowHeight: CGFloat { 22 }
    public var erMinWidth: CGFloat { 140 }
    public var erAttrFontSize: CGFloat { 11 }
}
#endif
