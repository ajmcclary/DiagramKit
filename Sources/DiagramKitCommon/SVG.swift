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
