// Linux-portable — deliberately NOT gated on UIKit/AppKit.
//
// The SVG renderers in this target are Linux-portable, so the default for
// their `font:` parameter cannot come from the Apple-only
// `DiagramFontResolver`. This is the single source of truth for the SVG
// `font-family` hint; `DiagramFontResolver.svgProportionalFamily` forwards
// here on Apple platforms.

/// Font-family strings emitted into SVG `font-family` attributes.
public enum DiagramSVGFontFamily {
    /// Proportional family for SVG output. A hint to the SVG consumer only;
    /// CoreText layout measurement uses
    /// `RenderTokens.defaultProportionalFontFamily` instead.
    public static let proportional = "Inter"

    /// CSS `font-family` fallback chain for proportional text.
    public static let proportionalChain = "\(proportional), Verdana, sans-serif"
}
