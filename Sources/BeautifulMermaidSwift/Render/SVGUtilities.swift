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
    public var id: String?
    public var width: Double
    public var height: Double
    public var viewBox: String?
    public var colors: DiagramColors
    public var transparent: Bool
    public var fontFamily: String
    public var includeHtmlLabelCSS: Bool
    public var accessibilityTitle: String?
    public var accessibilityDescription: String?

    public init(
        id: String? = nil,
        width: Double,
        height: Double,
        viewBox: String? = nil,
        colors: DiagramColors,
        transparent: Bool = false,
        fontFamily: String = "Inter",
        includeHtmlLabelCSS: Bool = false,
        accessibilityTitle: String? = nil,
        accessibilityDescription: String? = nil
    ) {
        self.id = id
        self.width = width
        self.height = height
        self.viewBox = viewBox
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

        // Inject role/aria if not already present
        var tag = svgTag
        if let cls = className {
            tag = tag.replacingOccurrences(of: "<svg ", with: "<svg class=\"\(SVG.escapeAttribute(cls))\" ")
        }
        if !tag.contains("role=") {
            tag = tag.replacingOccurrences(of: "<svg ", with: "<svg role=\"graphics-document\" aria-roledescription=\"diagram\" ")
        }
        if let extra = extraAttributes {
            tag = tag.replacingOccurrences(of: "<svg ", with: "<svg \(extra) ")
        }
        return tag
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
