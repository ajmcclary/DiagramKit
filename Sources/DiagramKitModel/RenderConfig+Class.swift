// Per-diagram-family constants forwarded from `RenderTokens`.
// These are the migration seam for the A5 `RenderConfig` split.
// The authoritative values live in `RenderTokens+Class.swift`.
// Remove this file once all consumers use `RenderTokens` directly.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics

extension RenderConfig {

    // MARK: - Class Diagram Constants (forwarded)

    public var classPadding: CGFloat { tokens.classPadding }
    public var classBoxPadX: CGFloat { tokens.classBoxPadX }
    public var classHeaderBaseHeight: CGFloat { tokens.classHeaderBaseHeight }
    public var classAnnotationHeight: CGFloat { tokens.classAnnotationHeight }
    public var classMemberRowHeight: CGFloat { tokens.classMemberRowHeight }
    public var classSectionPadY: CGFloat { tokens.classSectionPadY }
    public var classEmptySectionHeight: CGFloat { tokens.classEmptySectionHeight }
    public var classMinWidth: CGFloat { tokens.classMinWidth }
    public var classMemberFontSize: CGFloat { tokens.classMemberFontSize }
    public var classMemberFontWeight: Int { tokens.classMemberFontWeight }
    public var classNodeSpacing: CGFloat { tokens.classNodeSpacing }
    public var classLayerSpacing: CGFloat { tokens.classLayerSpacing }
}
#endif
