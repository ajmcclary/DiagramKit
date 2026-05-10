// Per-diagram-family constants extracted from `RenderConfig.swift`.
// Step toward the audit's `RenderConfig` split (A5 / #7 in the audit
// roadmap): grouping these by family makes it cheap to lift them into
// dedicated `SequenceConfig` / `ClassConfig` / `ERConfig` structs in a
// follow-up. No semantic change — values and access pattern unchanged.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics

extension RenderConfig {

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
