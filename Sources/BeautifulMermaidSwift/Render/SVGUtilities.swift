import Foundation

/// Canonical SVG utility namespace. All renderers should use these helpers
/// instead of defining local escaping functions or hand-building SVG wrappers.
public enum SVG {

    // MARK: - Escaping

    /// Escape text content for use between XML tags (e.g. `<text>...</text>`).
    /// Escapes `&`, `<`, `>`.
    public static func escapeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Escape a value for use in an XML attribute (e.g. `id="..."`).
    /// Escapes `&`, `<`, `>`, `"`, and `'`.
    /// Apostrophe is normalized to the numeric entity `&#39;` for maximum
    /// compatibility across SVG consumers (some parsers reject `&apos;`).
    public static func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

// MARK: - SVG Document Builder

/// Structured builder for the outer `<svg>` tag, accessibility metadata,
/// CSS style block, and closing tag. Replaces the per-renderer patterns of
/// calling `original_src_theme.svgOpenTag` / `buildStyleBlock` + hand-written
/// accessibility and `<defs>` wrappers.
public struct SVGDocumentBuilder: Sendable {
    public var width: Double
    public var height: Double
    public var colors: DiagramColors
    public var transparent: Bool
    public var fontFamily: String
    public var includeHtmlLabelCSS: Bool
    public var accessibilityTitle: String?
    public var accessibilityDescription: String?

    public init(
        width: Double,
        height: Double,
        colors: DiagramColors,
        transparent: Bool = false,
        fontFamily: String = "Inter",
        includeHtmlLabelCSS: Bool = false,
        accessibilityTitle: String? = nil,
        accessibilityDescription: String? = nil
    ) {
        self.width = width
        self.height = height
        self.colors = colors
        self.transparent = transparent
        self.fontFamily = fontFamily
        self.includeHtmlLabelCSS = includeHtmlLabelCSS
        self.accessibilityTitle = accessibilityTitle
        self.accessibilityDescription = accessibilityDescription
    }

    // MARK: - Open tag

    /// Returns the opening `<svg>` tag with viewBox, width, height, xmlns,
    /// role, aria-roledescription, and CSS custom properties.
    public func open(className: String? = nil, extraAttributes: String? = nil) -> String {
        let themeColors = original_src_theme.DiagramColors(
            bg: colors.bg,
            fg: colors.fg,
            line: colors.line,
            accent: colors.accent,
            muted: colors.muted,
            surface: colors.surface,
            border: colors.border,
            noteBkg: colors.noteBkg,
            noteBorder: colors.noteBorder
        )
        let svgTag = original_src_theme.svgOpenTag(width, height, themeColors, transparent)

        // Collect additional attributes to inject into the opening tag.
        var extraAttrs: [String] = []
        if let cls = className {
            extraAttrs.append("class=\"\(SVG.escapeAttribute(cls))\"")
        }
        if !svgTag.contains("role=") {
            extraAttrs.append("role=\"graphics-document\" aria-roledescription=\"diagram\"")
        }
        if let extra = extraAttributes {
            extraAttrs.append(extra)
        }
        guard !extraAttrs.isEmpty else { return svgTag }
        return svgTag.replacingOccurrences(of: "<svg ", with: "<svg \(extraAttrs.joined(separator: " ")) ")
    }

    // MARK: - Accessibility

    /// Returns `<title>` and `<desc>` elements if the corresponding fields
    /// are non-empty.
    public func accessibility() -> String {
        var parts: [String] = []
        if let title = accessibilityTitle, !title.isEmpty {
            parts.append("<title>\(SVG.escapeText(title))</title>")
        }
        if let desc = accessibilityDescription, !desc.isEmpty {
            parts.append("<desc>\(SVG.escapeText(desc))</desc>")
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - Style block

    /// Returns the CSS `<style>` block with font imports and derived custom
    /// property definitions.
    public func style() -> String {
        original_src_theme.buildStyleBlock(fontFamily, includeHtmlLabelCSS)
    }

    // MARK: - Close tag

    /// Returns `</svg>`.
    public func close() -> String { "</svg>" }
}
