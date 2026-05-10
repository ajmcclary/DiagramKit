// Per-diagram-family constants extracted from `RenderConfig.swift`.
// Step toward the audit's `RenderConfig` split (A5 / #7 in the audit
// roadmap): grouping these by family makes it cheap to lift them into
// dedicated `SequenceConfig` / `ClassConfig` / `ERConfig` structs in a
// follow-up. No semantic change — values and access pattern unchanged.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics

extension RenderConfig {

    // MARK: - ER Diagram Constants

    public var erPadding: CGFloat { 40 }
    public var erBoxPadX: CGFloat { 14 }
    public var erHeaderHeight: CGFloat { 34 }
    public var erRowHeight: CGFloat { 22 }
    public var erMinWidth: CGFloat { 140 }
    public var erAttrFontSize: CGFloat { 11 }
}
#endif
