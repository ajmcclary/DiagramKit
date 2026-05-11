import Foundation
import DiagramKitCommon

// SVG escape namespace moved to DiagramKitCommon/SVG.swift

// MARK: - SVG Document Builder

/// Structured builder for the outer `<svg>` tag, accessibility metadata,
/// CSS style block, and closing tag. Replaces the per-renderer patterns of
/// calling `original_src_theme.svgOpenTag` / `buildStyleBlock` + hand-written
/// accessibility and `<defs>` wrappers.
///
/// Three optional fields control root-element rendering beyond the basic
/// viewBox + dimensions:
/// - `useMaxWidth`: when `true`, emits `width="100%"` with a `max-width`
///   style and `preserveAspectRatio="xMinYMin meet"` instead of fixed
///   `width`/`height`.
/// - `viewBoxX` / `viewBoxY`: non-zero viewBox origin offsets, forwarded
///   to `original_src_theme.svgOpenTag(viewBoxX:viewBoxY:)`.
/// - `rootStyles`: additional CSS custom properties injected into the
///   root `<svg>` style attribute (e.g. `"--line: #333"`).
public struct SVGDocumentBuilder: Sendable {
    public var width: Double
    public var height: Double
    public var colors: DiagramColors
    public var transparent: Bool
    public var fontFamily: String
    public var includeHtmlLabelCSS: Bool
    public var accessibilityTitle: String?
    public var accessibilityDescription: String?
    public var useMaxWidth: Bool
    public var viewBoxX: Double
    public var viewBoxY: Double
    public var rootStyles: [String]

    public init(
        width: Double,
        height: Double,
        colors: DiagramColors,
        transparent: Bool = false,
        fontFamily: String = "Inter",
        includeHtmlLabelCSS: Bool = false,
        accessibilityTitle: String? = nil,
        accessibilityDescription: String? = nil,
        useMaxWidth: Bool = false,
        viewBoxX: Double = 0,
        viewBoxY: Double = 0,
        rootStyles: [String] = []
    ) {
        self.width = width
        self.height = height
        self.colors = colors
        self.transparent = transparent
        self.fontFamily = fontFamily
        self.includeHtmlLabelCSS = includeHtmlLabelCSS
        self.accessibilityTitle = accessibilityTitle
        self.accessibilityDescription = accessibilityDescription
        self.useMaxWidth = useMaxWidth
        self.viewBoxX = viewBoxX
        self.viewBoxY = viewBoxY
        self.rootStyles = rootStyles
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
        var svgTag = original_src_theme.svgOpenTag(
            width, height, themeColors, transparent,
            viewBoxX: viewBoxX, viewBoxY: viewBoxY
        )

        if useMaxWidth {
            let wStr = _formatSvgNum(width)
            svgTag = svgTag.replacingOccurrences(of: "width=\"\(wStr)\"", with: "width=\"100%\"")
            let maxStyle = "max-width: \(wStr)px;"
            if let styleStart = svgTag.range(of: "style=\"") {
                svgTag.insert(contentsOf: maxStyle, at: styleStart.upperBound)
            }
            if !svgTag.contains("preserveAspectRatio") {
                svgTag = svgTag.replacingOccurrences(
                    of: "<svg ",
                    with: "<svg preserveAspectRatio=\"xMinYMin meet\" "
                )
            }
        }

        // Inject root-level custom properties into the style attribute.
        if !rootStyles.isEmpty {
            let extra = rootStyles.joined(separator: ";") + ";"
            if let styleStart = svgTag.range(of: "style=\"") {
                svgTag.insert(contentsOf: extra, at: styleStart.upperBound)
            }
        }

        // Collect additional attributes to inject into the opening tag.
        var extraAttrs: [String] = []
        if let cls = className {
            extraAttrs.append("class=\"\(SVG.escapeAttribute(cls))\"")
        }
        let extraHasRoleDescription = extraAttributes?.contains("aria-roledescription") ?? false
        if !svgTag.contains("role=") {
            extraAttrs.append(
                extraHasRoleDescription
                    ? "role=\"graphics-document\""
                    : "role=\"graphics-document\" aria-roledescription=\"diagram\""
            )
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

    // MARK: - Private

    private func _formatSvgNum(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }
}
