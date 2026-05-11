// This file is the migration seam for CG renderers that call
// `DiagramFontResolver.proportional(config, size:, weight:)` etc.
// All logic now delegates to the model-layer `DiagramFontResolver`
// (the struct in `DiagramKitModel`). This enum will be deleted in
// Phase 7 of the A5 `RenderConfig` split once all callers have been
// migrated to use `self.fontResolver` on `DiagramRenderer`.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum DiagramFontResolver {

    /// Proportional (non-monospace) font. Delegates to the model-layer
    /// `DiagramFontResolver.proportionalFont(size:weight:)`.
    @available(*, deprecated, message: "Use renderer.fontResolver.proportionalFont(size:weight:) instead")
    static func proportional(
        _ config: RenderConfig,
        size: CGFloat,
        weight: Int = 400
    ) -> BMFont {
        config.fontResolver.proportionalFont(size: size, weight: weight)
    }

    /// Convenience overload accepting a `BMFont.Weight`.
    @available(*, deprecated, message: "Use renderer.fontResolver.proportionalFont(size:weight:) instead")
    static func proportional(
        _ config: RenderConfig,
        size: CGFloat,
        weight: BMFont.Weight
    ) -> BMFont {
        config.fontResolver.proportionalFont(size: size, weight: weight)
    }

    /// Bold proportional font.
    @available(*, deprecated, message: "Use renderer.fontResolver.boldProportionalFont(size:) instead")
    static func boldProportional(_ config: RenderConfig, size: CGFloat) -> BMFont {
        config.fontResolver.boldProportionalFont(size: size)
    }

    /// Monospace font.
    @available(*, deprecated, message: "Use renderer.fontResolver.monoFont(size:weight:) instead")
    static func mono(
        _ config: RenderConfig,
        size: CGFloat,
        weight: BMFont.Weight = .regular
    ) -> BMFont {
        config.fontResolver.monoFont(size: size, weight: weight)
    }
}
#endif
