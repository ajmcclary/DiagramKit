// Apple-only — depends on BMFont (UIKit/AppKit) and CoreText.
// Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics
import CoreText
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Diagram Font Resolver

/// Resolves fonts, creates `CTFont` / `BMFont` instances, and provides
/// SVG `font-family` strings using the centralized `RenderTokens`
/// configuration.
///
/// This type consolidates all font-resolution logic that was previously
/// scattered across `RenderConfig` (instance methods), the CG-layer
/// `DiagramFontResolver` (static helpers), the base `DiagramRenderer`
/// (italic font helpers), and individual renderer files (Ishikawa,
/// EventModeling local helpers).
///
/// Call sites should use this resolver instead of calling
/// `BMFont.systemFont` or `BMFont(name:size:)` directly. Direct calls
/// bypass the bundled-font determinism guarantee.
public struct DiagramFontResolver: Sendable {
    public let tokens: RenderTokens

    public init(tokens: RenderTokens = .shared) {
        self.tokens = tokens
    }

    /// Shared instance using `RenderTokens.shared`.
    public static let shared = DiagramFontResolver()

    // MARK: - SVG font-family strings

    /// Proportional font family suitable for `font-family` in SVG output.
    ///
    /// Always returns `"Inter"` for SVG output. SVG `font-family` strings are
    /// hints to the consumer (browser, viewer); the actual font used for
    /// CoreText layout measurement is independent and comes from
    /// `RenderTokens.defaultProportionalFontFamily` (typically `"Noto Sans"`,
    /// bundled for snapshot determinism).
    public var svgProportionalFamily: String { "Inter" }

    /// Alias for `svgProportionalFamily` kept for call-site compatibility.
    public var svgFontFamily: String { svgProportionalFamily }

    /// Monospace font family suitable for `font-family` in SVG output.
    /// Falls back to `"Menlo"` when `defaultFontFamily` is `nil`.
    public var svgMonoFamily: String {
        tokens.defaultFontFamily ?? "Menlo"
    }

    /// Alias for `svgMonoFamily` kept for call-site compatibility.
    public var svgMonoFontFamily: String { svgMonoFamily }

    /// CSS `font-family` fallback chain for proportional text.
    public var svgProportionalFamilyChain: String {
        "\(svgProportionalFamily), Verdana, sans-serif"
    }

    /// CSS `font-family` fallback chain for monospace text.
    public var svgMonoFamilyChain: String {
        "\(svgMonoFamily), Courier, monospace"
    }

    // MARK: - CTFont helpers (for layout code)

    /// Create a proportional `CTFont` using the configured proportional
    /// font family. Falls back to `"TrebuchetMS"`.
    public func proportionalCTFont(size: CGFloat) -> CTFont {
        let family = tokens.defaultProportionalFontFamily ?? "TrebuchetMS"
        return CTFontCreateWithName(family as CFString, size, nil)
    }

    /// Monospace `CTFont` using the configured default font family.
    /// Previously `RenderTokens.layoutMonoCTFont(size:)`.
    public func monospaceCTFont(size: CGFloat) -> CTFont {
        let family = tokens.defaultFontFamily ?? "Menlo"
        return CTFontCreateWithName(family as CFString, size, nil)
    }

    // MARK: - CSS weight mapping

    /// Maps a CSS-style numeric weight (100..900) to a `BMFont.Weight`.
    public static func bmWeight(forCSS weight: Int) -> BMFont.Weight {
        switch weight {
        case ..<150:    return .ultraLight
        case 150..<250: return .thin
        case 250..<350: return .light
        case 350..<450: return .regular
        case 450..<550: return .medium
        case 550..<650: return .semibold
        case 650..<750: return .bold
        case 750..<850: return .heavy
        default:        return .black
        }
    }

    /// Convenience mapping from weight integer to `BMFont.Weight`.
    public static func fontWeight(from weight: Int) -> BMFont.Weight {
        switch weight {
        case 100: return .ultraLight
        case 200: return .thin
        case 300: return .light
        case 400: return .regular
        case 500: return .medium
        case 600: return .semibold
        case 700: return .bold
        case 800: return .heavy
        case 900: return .black
        default: return .regular
        }
    }

    // MARK: - Core font resolution

    /// Resolves a monospace font, preferring `defaultFontFamily` when set.
    public func defaultFont(size: CGFloat, weight: Int = 400) -> BMFont {
        if let family = tokens.defaultFontFamily {
            if weight >= 550 {
                let boldCandidates = ["\(family)-Bold", "\(family) Bold"]
                for name in boldCandidates {
                    if let f = BMFont(name: name, size: size) { return f }
                }
            }
            if let named = BMFont(name: family, size: size) {
                return named
            }
        }
        return BMFont.monospacedSystemFont(ofSize: size, weight: Self.bmWeight(forCSS: weight))
    }

    /// Resolves a proportional (non-monospace) font for the given size and weight.
    public func proportionalFont(size: CGFloat, weight: Int = 400) -> BMFont {
        if let family = tokens.defaultProportionalFontFamily {
            let suffix: String?
            switch weight {
            case ..<350:    suffix = nil
            case 350..<450: suffix = nil
            case 450..<650: suffix = nil
            case 650..<850: suffix = "Bold"
            default:        suffix = "Bold"
            }
            if let s = suffix {
                let candidates = ["\(family)-\(s)", "\(family) \(s)"]
                for name in candidates {
                    if let f = BMFont(name: name, size: size) { return f }
                }
            }
            if let named = BMFont(name: family, size: size) {
                return named
            }
        }
        return BMFont.systemFont(ofSize: size, weight: Self.bmWeight(forCSS: weight))
    }

    /// Shorthand for proportional font with a `BMFont.Weight` literal.
    /// Convenience for call sites that use `.regular` / `.medium` / `.semibold` / `.bold`.
    public func proportionalFont(size: CGFloat, weight: BMFont.Weight) -> BMFont {
        proportionalFont(size: size, weight: Self._cssWeight(from: weight))
    }

    /// Bold proportional font. Convenience for sites that previously
    /// called `BMFont.systemFont(ofSize:weight: .bold)`.
    public func boldProportionalFont(size: CGFloat) -> BMFont {
        proportionalFont(size: size, weight: 700)
    }

    /// Monospace font with explicit `BMFont.Weight`.
    public func monoFont(size: CGFloat, weight: BMFont.Weight = .regular) -> BMFont {
        if let family = tokens.defaultFontFamily,
           let f = BMFont(name: family, size: size) {
            return f
        }
        return BMFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    // MARK: - Semantic font helpers

    /// Resolve the node-label font.
    public func nodeLabelFont(family: String? = nil) -> BMFont {
        if let family,
           let f = BMFont(name: family, size: tokens.fontSizeNodeLabel) {
            return f
        }
        return proportionalFont(size: tokens.fontSizeNodeLabel, weight: tokens.fontWeightNodeLabel)
    }

    /// Resolve the edge-label font.
    public func edgeLabelFont(family: String? = nil) -> BMFont {
        if let family,
           let f = BMFont(name: family, size: tokens.fontSizeEdgeLabel) {
            return f
        }
        return proportionalFont(size: tokens.fontSizeEdgeLabel, weight: tokens.fontWeightEdgeLabel)
    }

    /// Resolve the group-header font.
    public func groupHeaderFont(family: String? = nil) -> BMFont {
        if let family,
           let f = BMFont(name: family, size: tokens.fontSizeGroupHeader) {
            return f
        }
        return proportionalFont(size: tokens.fontSizeGroupHeader, weight: tokens.fontWeightGroupHeader)
    }

    // MARK: - Italic font variants

    /// Resolves an italic proportional font, preferring the configured
    /// proportional family, then the system font with an italic trait.
    /// Previously `DiagramRenderer._italicSystemFont(size:weight:)`.
    public func italicProportionalFont(size: CGFloat, weight: CGFloat = 0.0) -> BMFont {
        if let family = tokens.defaultProportionalFontFamily {
            let italicCandidates = ["\(family)-Italic", "\(family) Italic"]
            for name in italicCandidates {
                if let f = BMFont(name: name, size: size) { return f }
            }
            if let baseFont = BMFont(name: family, size: size) {
                #if targetEnvironment(macCatalyst) || canImport(UIKit)
                if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) {
                    return BMFont(descriptor: descriptor, size: size)
                }
                return baseFont
                #elseif canImport(AppKit)
                return NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                #endif
            }
        }
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        let baseFont = BMFont.systemFont(ofSize: size, weight: UIFont.Weight(weight))
        if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) {
            return BMFont(descriptor: descriptor, size: size)
        }
        return baseFont
        #elseif canImport(AppKit)
        let baseFont = BMFont.systemFont(ofSize: size, weight: NSFont.Weight(weight))
        return NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        #endif
    }

    /// Resolves an italic monospace font, preferring an italic variant of
    /// the configured mono family, then "Menlo-Italic", then a fallback.
    /// Previously `DiagramRenderer._italicMonoFont(size:)`.
    public func italicMonoFont(size: CGFloat) -> BMFont {
        if let family = tokens.defaultFontFamily {
            let italicCandidates = ["\(family)-Italic", "\(family) Italic"]
            for name in italicCandidates {
                if let f = BMFont(name: name, size: size) { return f }
            }
            if let f = BMFont(name: family, size: size) { return f }
        }
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        return UIFont(name: "Menlo-Italic", size: size)
            ?? UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        #elseif canImport(AppKit)
        return NSFont(name: "Menlo-Italic", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        #endif
    }

    /// Bold monospace font. Convenience for call sites that need a bold
    /// mono variant. Previously inlined in Ishikawa/EventModeling renderers.
    public func boldMonoFont(size: CGFloat) -> BMFont {
        if let family = tokens.defaultFontFamily {
            let candidates = ["\(family)-Bold", "\(family) Bold"]
            for name in candidates {
                if let f = BMFont(name: name, size: size) { return f }
            }
            if let f = BMFont(name: family, size: size) { return f }
        }
        return BMFont.monospacedSystemFont(ofSize: size, weight: .bold)
    }

    // MARK: - Private helpers

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
}
#endif
