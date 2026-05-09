import Foundation
import CoreGraphics
import CoreText

/// SVG-oriented token bag derived from `RenderConfig`.
///
/// `RenderTokens` bridges the gap between the CG-oriented `RenderConfig`
/// (which returns `BMFont`/`CTFont` instances) and the SVG renderers
/// (which need `font-family` strings and geometry constants as raw
/// values). Every SVG renderer should derive its font family, padding,
/// and spacing through `RenderTokens` rather than hardcoding `"Inter"`,
/// `"Menlo"`, or literal `CGFloat` values.
public struct RenderTokens: Sendable {
    public let config: RenderConfig

    // MARK: - SVG font-family strings

    /// Proportional font family suitable for `font-family` in SVG output.
    ///
    /// Falls back to `"Inter"` when `defaultProportionalFontFamily` is `nil`,
    /// matching the historical default that existed before `RenderConfig`
    /// was introduced.
    public var svgFontFamily: String {
        config.defaultProportionalFontFamily ?? "Inter"
    }

    /// Monospace font family suitable for `font-family` in SVG output.
    ///
    /// Falls back to `"Menlo"` when `defaultFontFamily` is `nil`.
    public var svgMonoFontFamily: String {
        config.defaultFontFamily ?? "Menlo"
    }

    // MARK: - Font helpers (Bridged to `BMFont`/`CTFont`)

    /// Proportional font for CoreText-based layout measurement.
    public func layoutFont(size: CGFloat, weight: Int = 400) -> BMFont {
        config.proportionalFont(size: size, weight: weight)
    }

    /// Monospace font for CoreText-based layout measurement.
    public func layoutMonoFont(size: CGFloat, weight: Int = 400) -> BMFont {
        config.defaultFont(size: size, weight: weight)
    }

    /// Monospace `CTFont` for direct CoreText measurement (used by
    /// `src_ishikawa_layout.swift` and similar JS-ported layout code).
    public func layoutMonoCTFont(size: CGFloat) -> CTFont {
        let font = layoutMonoFont(size: size)
        return font as CTFont
    }

    // MARK: - Geometry constants (delegated from `RenderConfig`)

    public var nodePadding: CGSize { config.nodePadding }
    public var graphPadding: CGFloat { config.graphPadding }
    public var nodeSpacing: CGFloat { config.nodeSpacing }
    public var layerSpacing: CGFloat { config.layerSpacing }

    public var nodePaddingHorizontal: CGFloat { config.nodePaddingHorizontal }
    public var nodePaddingVertical: CGFloat { config.nodePaddingVertical }
    public var nodePaddingDiamondExtra: CGFloat { config.nodePaddingDiamondExtra }

    public var minimumNodeWidth: CGFloat { config.minimumNodeWidth }
    public var minimumNodeHeight: CGFloat { config.minimumNodeHeight }

    // MARK: - Initialization

    public init(config: RenderConfig = .shared) {
        self.config = config
    }

    /// Shared instance using `RenderConfig.shared`.
    public static let shared = RenderTokens()
}
