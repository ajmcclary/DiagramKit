// Extracted from Render/SVGUtilities.swift during Stage 1 module split.
// The SVG escape namespace is fundamental string-utility code with no
// rendering dependencies; it lives in Common so Model and other lower
// layers can use it. The full SVGDocumentBuilder stays in the Rendering
// layer (it depends on DiagramColors / theming).

import Foundation

/// Canonical SVG utility namespace. All renderers should use these helpers
/// instead of defining local escaping functions or hand-building SVG wrappers.
public enum SVG {

    // MARK: - Escaping

    /// Escape text for an XML text node (e.g. `<text>...</text>`), a
    /// `<style>` block, or a double-quoted attribute value.
    /// Escapes `&`, `<`, `>` and `"`.
    ///
    /// The renderers use this helper in all three positions; it used to
    /// leave `"` alone, so in an attribute a value such as
    /// `red" onload="…` added an attribute, and a `font-family` of
    /// `"Open Sans"` inside `style="…"` made the SVG unparseable. With `"`
    /// escaped there is one escaping path for every position the renderers
    /// write (all attributes are double-quoted).
    public static func escapeText(_ value: String) -> String {
        xmlCharacters(value)
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Escape a value for use in an XML attribute (e.g. `id="..."`).
    /// Escapes `&`, `<`, `>`, `"`, and `'`.
    /// Apostrophe is normalized to the numeric entity `&#39;` for maximum
    /// compatibility across SVG consumers (some parsers reject `&apos;`).
    public static func escapeAttribute(_ value: String) -> String {
        xmlCharacters(value)
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// `value` without the characters XML 1.0 forbids (C0 controls other
    /// than tab, newline and carriage return, and U+FFFE/U+FFFF); one of
    /// them anywhere makes the whole SVG unparseable.
    public static func xmlCharacters(_ value: String) -> String {
        guard value.unicodeScalars.contains(where: _isXMLForbidden) else { return value }
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: value.unicodeScalars.filter { !_isXMLForbidden($0) })
        return String(scalars)
    }

    private static func _isXMLForbidden(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return (v < 0x20 && v != 0x09 && v != 0x0A && v != 0x0D) || v == 0xFFFE || v == 0xFFFF
    }

    /// A theme or style value for a CSS position — a `<style>` block or a
    /// `style="…"` / presentation attribute. Returns `value` when
    /// `_isSafeCSSThemeValue` accepts it (no `<`, `>`, quotes, braces, `;`,
    /// `url(` …), so it can neither close the attribute nor the `<style>`
    /// element; otherwise `fallback`. Theme values used to be interpolated
    /// raw, so `cScale0: "red}</style><script>…"` produced a script
    /// element.
    public static func cssValue(_ value: String?, fallback: String) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty,
              _isSafeCSSThemeValue(value) else { return fallback }
        return value
    }
}
