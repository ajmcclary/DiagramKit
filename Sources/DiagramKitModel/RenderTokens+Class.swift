// Per-diagram-family constants extracted from `RenderConfig.swift`.
// These are now owned by `RenderTokens` as the source of truth, with
// `RenderConfig` forwarding during the migration to the three-way
// `RenderConfig` split (A5).
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics

extension RenderTokens {

    // MARK: - Class Diagram Constants

    public var classPadding: CGFloat { 40 }
    public var classBoxPadX: CGFloat { 8 }
    public var classHeaderBaseHeight: CGFloat { 32 }
    public var classAnnotationHeight: CGFloat { 16 }
    public var classMemberRowHeight: CGFloat { 20 }
    public var classSectionPadY: CGFloat { 8 }
    public var classEmptySectionHeight: CGFloat { 8 }
    public var classMinWidth: CGFloat { 120 }
    public var classMemberFontSize: CGFloat { 11 }
    public var classMemberFontWeight: Int { 400 }
    public var classNodeSpacing: CGFloat { 40 }
    public var classLayerSpacing: CGFloat { 60 }
}
#endif
