import Foundation

// MARK: - CSS color / style safety helpers
//
// Defensive string helpers used at frontmatter bind time and at SVG
// renderer sinks. They reject injection payloads while allowing the
// legitimate CSS forms DiagramKit themes use (hex, rgb/a, hsl/a, named
// colors, CSS variables, transparent/currentColor/none).

/// Characters / substrings that must never appear inside a CSS color or
/// style value emitted into SVG attributes.
private let _dangerousCSSSubstrings: [String] = [
    "<", ">", "{", "}", "\"", "'", "`", "\\", "\n", "\r",
    "url(", "expression(", "javascript:", "@import", "import ",
]

/// Standard CSS named colors. Any other name is rejected.
private let _knownCSSColorNames: Set<String> = [
    "aliceblue", "antiquewhite", "aqua", "aquamarine", "azure", "beige",
    "bisque", "black", "blanchedalmond", "blue", "blueviolet", "brown",
    "burlywood", "cadetblue", "chartreuse", "chocolate", "coral",
    "cornflowerblue", "cornsilk", "crimson", "cyan", "darkblue", "darkcyan",
    "darkgoldenrod", "darkgray", "darkgrey", "darkgreen", "darkkhaki",
    "darkmagenta", "darkolivegreen", "darkorange", "darkorchid", "darkred",
    "darksalmon", "darkseagreen", "darkslateblue", "darkslategray",
    "darkslategrey", "darkturquoise", "darkviolet", "deeppink", "deepskyblue",
    "dimgray", "dimgrey", "dodgerblue", "firebrick", "floralwhite",
    "forestgreen", "fuchsia", "gainsboro", "ghostwhite", "gold",
    "goldenrod", "gray", "grey", "green", "greenyellow", "honeydew",
    "hotpink", "indianred", "indigo", "ivory", "khaki", "lavender",
    "lavenderblush", "lawngreen", "lemonchiffon", "lightblue", "lightcoral",
    "lightcyan", "lightgoldenrodyellow", "lightgray", "lightgrey",
    "lightgreen", "lightpink", "lightsalmon", "lightseagreen", "lightskyblue",
    "lightslategray", "lightslategrey", "lightsteelblue", "lightyellow",
    "lime", "limegreen", "linen", "magenta", "maroon", "mediumaquamarine",
    "mediumblue", "mediumorchid", "mediumpurple", "mediumseagreen",
    "mediumslateblue", "mediumspringgreen", "mediumturquoise",
    "mediumvioletred", "midnightblue", "mintcream", "mistyrose", "moccasin",
    "navajowhite", "navy", "oldlace", "olive", "olivedrab", "orange",
    "orangered", "orchid", "palegoldenrod", "palegreen", "paleturquoise",
    "palevioletred", "papayawhip", "peachpuff", "peru", "pink", "plum",
    "powderblue", "purple", "rebeccapurple", "red", "rosybrown",
    "royalblue", "saddlebrown", "salmon", "sandybrown", "seagreen",
    "seashell", "sienna", "silver", "skyblue", "slateblue", "slategray",
    "slategrey", "snow", "springgreen", "steelblue", "tan", "teal",
    "thistle", "tomato", "turquoise", "violet", "wheat", "white",
    "whitesmoke", "yellow", "yellowgreen",
    "transparent", "currentcolor", "none",
]

/// Returns `true` if `value` is a syntactically safe CSS color that can be
/// placed inside `fill="..."`, `stroke="..."`, or a CSS rule value.
public func _isSafeCSSColor(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    for bad in _dangerousCSSSubstrings {
        if trimmed.localizedStandardContains(bad) { return false }
    }

    // Hex: #RGB, #RGBA, #RRGGBB, #RRGGBBAA
    if trimmed.hasPrefix("#") {
        let hex = String(trimmed.dropFirst())
        let validCounts = [3, 4, 6, 8]
        guard validCounts.contains(hex.count) else { return false }
        return hex.allSatisfy { $0.isHexDigit }
    }

    // Functional notations: rgb(...), rgba(...), hsl(...), hsla(...)
    let lower = trimmed.lowercased()
    for prefix in ["rgb(", "rgba(", "hsl(", "hsla("] {
        if lower.hasPrefix(prefix) && trimmed.hasSuffix(")") { return true }
    }

    // CSS variable: var(--name) or var(--name, fallback)
    if lower.hasPrefix("var(") && trimmed.hasSuffix(")") {
        let inner = String(trimmed.dropFirst(4).dropLast())
        let beforeComma = inner.split(separator: ",", maxSplits: 1).first ?? Substring(inner)
        let varName = String(beforeComma).trimmingCharacters(in: .whitespaces)
        guard varName.hasPrefix("--") else { return false }
        let nameBody = String(varName.dropFirst(2))
        return nameBody.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    // Named colors
    return _knownCSSColorNames.contains(lower)
}

/// Returns a safe CSS color, falling back to `default` and appending a
/// `.styleDrop` diagnostic when the input is rejected.
public func _safeCSSColor(
    _ value: String,
    default fallback: String,
    diagnostics: inout [DiagramDiagnostic],
    subject: String
) -> String {
    if _isSafeCSSColor(value) { return value }
    diagnostics.append(.lossyTransform(.styleDrop, message: "Rejected unsafe \(subject) color '\(value.prefix(80))'; using fallback."))
    return fallback
}

/// Returns `true` if `value` is safe to place inside an inline
/// `style="..."` attribute value. Rejects anything that could close the
/// attribute or inject extra declarations (`;`, `}`), or run script
/// (`url(`, `expression(`, etc.).
public func _isSafeCSSStyleValue(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return true }

    for bad in _dangerousCSSSubstrings {
        if trimmed.localizedStandardContains(bad) { return false }
    }

    // Do not allow semicolons or closing braces inside a single declaration
    // value; they would break out of the inline style block.
    if trimmed.contains(";") || trimmed.contains("}") { return false }

    // Reject anything that looks like a function call other than the safe
    // CSS color functions already handled by `_isSafeCSSColor`.
    if trimmed.contains("(") || trimmed.contains(")") { return false }

    return true
}

/// Returns a safe inline style value, falling back to `default` and
/// appending a `.styleDrop` diagnostic when the input is rejected.
public func _safeCSSStyleValue(
    _ value: String,
    default fallback: String,
    diagnostics: inout [DiagramDiagnostic],
    subject: String
) -> String {
    if _isSafeCSSStyleValue(value) { return value }
    diagnostics.append(.lossyTransform(.styleDrop, message: "Rejected unsafe \(subject) style value '\(value.prefix(80))'; using fallback."))
    return fallback
}

/// Sanitizes a string intended for an SVG `class` attribute. Keeps only
/// whitespace-separated `[A-Za-z0-9_-]+` tokens and collapses multiple
/// spaces.
public func _sanitizeSVGClassTokens(_ value: String) -> String {
    let tokens = value.split(separator: " ", omittingEmptySubsequences: true)
    let sanitized = tokens.compactMap { token -> String? in
        let s = String(token)
        guard s.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
            return nil
        }
        return s
    }
    return sanitized.joined(separator: " ")
}

/// Sanitizes a string intended for an SVG `id` attribute. Keeps only
/// `[A-Za-z0-9_-]` characters.
public func _sanitizeSVGIdToken(_ value: String) -> String {
    String(value.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
}

/// Escapes raw text so it is safe inside an HTML `<span>` or other
/// element context used by the ASCII renderer.
public func _escapeHTMLText(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}
