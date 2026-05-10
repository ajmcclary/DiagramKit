#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Resolves fonts on behalf of CG renderers, honoring
/// `RenderConfig.defaultProportionalFontFamily` and
/// `RenderConfig.defaultFontFamily` (mono).
///
/// CG renderers should use this helper instead of calling
/// `BMFont.systemFont` directly. Direct system-font calls leak platform
/// font drift into image snapshots and bypass the bundled-font
/// determinism guarantee documented in CLAUDE.md.
enum DiagramFontResolver {

    /// Proportional (non-monospace) font. Falls back to `BMFont.systemFont`
    /// only when neither the configured family nor any weight-suffixed
    /// variant resolves.
    static func proportional(
        _ config: RenderConfig,
        size: CGFloat,
        weight: Int = 400
    ) -> BMFont {
        config.proportionalFont(size: size, weight: weight)
    }

    /// Bold proportional font. Convenience for sites that previously
    /// called `BMFont.systemFont(ofSize:weight: .bold)`.
    static func boldProportional(_ config: RenderConfig, size: CGFloat) -> BMFont {
        config.proportionalFont(size: size, weight: 700)
    }

    /// Monospace font, honoring `defaultFontFamily` (Noto Sans Mono by
    /// default). Falls back to `BMFont.monospacedSystemFont` only when no
    /// configured family resolves.
    static func mono(
        _ config: RenderConfig,
        size: CGFloat,
        weight: BMFont.Weight = .regular
    ) -> BMFont {
        if let family = config.defaultFontFamily,
           let f = BMFont(name: family, size: size) {
            return f
        }
        return BMFont.monospacedSystemFont(ofSize: size, weight: weight)
    }
}
#endif
