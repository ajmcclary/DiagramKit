import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Diagram Font Resolver

/// Resolves font families and creates `CTFont` instances using the
/// centralized `RenderConfig`/`RenderTokens` values.
///
/// Replaces hardcoded font names (e.g. `"TrebuchetMS"`, `"Helvetica"`)
/// with configurable defaults, improving snapshot determinism and
/// making it possible to reason about which diagrams honor
/// `RenderConfig.defaultFontFamily` or `defaultProportionalFontFamily`.
public struct DiagramFontResolver: Sendable {
    public let tokens: RenderTokens

    public init(tokens: RenderTokens = .shared) {
        self.tokens = tokens
    }

    /// Create a proportional `CTFont` using the configured proportional
    /// font family. Falls back to `"TrebuchetMS"` if no proportional
    /// family is configured.
    public func proportionalCTFont(size: CGFloat) -> CTFont {
        let family = tokens.config.defaultProportionalFontFamily ?? "TrebuchetMS"
        return CTFontCreateWithName(family as CFString, size, nil)
    }

    /// Monospace `CTFont` using the configured default font family.
    public func monospaceCTFont(size: CGFloat) -> CTFont {
        return tokens.layoutMonoCTFont(size: size)
    }

    /// SVG `font-family` string for proportional text.
    /// Suitable for embedding in SVG CSS classes.
    public var svgProportionalFamily: String {
        tokens.svgFontFamily
    }

    /// SVG `font-family` string for monospace text.
    public var svgMonoFamily: String {
        tokens.svgMonoFontFamily
    }

    /// CSS `font-family` fallback chain for proportional text.
    /// Includes generic fallbacks (Verdana, sans-serif) for SVG.
    public var svgProportionalFamilyChain: String {
        let primary = tokens.svgFontFamily
        return "\(primary), Verdana, sans-serif"
    }

    /// CSS `font-family` fallback chain for monospace text.
    public var svgMonoFamilyChain: String {
        let primary = tokens.svgMonoFontFamily
        return "\(primary), Courier, monospace"
    }
}
