// Per-diagram-family constants extracted from `RenderConfig.swift`.
// Step toward the audit's `RenderConfig` split (A5 / #7 in the audit
// roadmap): grouping these by family makes it cheap to lift them into
// dedicated `SequenceConfig` / `ClassConfig` / `ERConfig` structs in a
// follow-up. No semantic change — values and access pattern unchanged.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics

extension RenderConfig {

    // MARK: - Sequence Diagram Constants

    public var sequenceLoopH: CGFloat { 20 }
    public var sequenceTabHeight: CGFloat { 18 }
    public var sequenceFoldSize: CGFloat { 6 }
}
#endif
