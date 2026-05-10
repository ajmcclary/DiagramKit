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

    /// Convenience overload accepting a `BMFont.Weight` instead of a CSS
    /// weight integer. Lets call sites keep their `.regular` / `.medium` /
    /// `.semibold` / `.bold` literals.
    static func proportional(
        _ config: RenderConfig,
        size: CGFloat,
        weight: BMFont.Weight
    ) -> BMFont {
        proportional(config, size: size, weight: _cssWeight(from: weight))
    }

    /// Bold proportional font. Convenience for sites that previously
    /// called `BMFont.systemFont(ofSize:weight: .bold)`.
    static func boldProportional(_ config: RenderConfig, size: CGFloat) -> BMFont {
        config.proportionalFont(size: size, weight: 700)
    }

    private static func _cssWeight(from w: BMFont.Weight) -> Int {
        switch w {
        case .ultraLight: return 100
        case .thin:       return 200
        case .light:      return 300
        case .regular:    return 400
        case .medium:     return 500
        case .semibold:   return 600
        case .bold:       return 700
        case .heavy:      return 800
        case .black:      return 900
        default:          return 400
        }
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
