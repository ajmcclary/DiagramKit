/// Returns true when the SVG contains no NaN/Infinity numeric literals.
/// Looks for the patterns Swift's `String(describing: Double.nan)` emits
/// when serialized into SVG (`nan`, `-nan`, `inf`, `-inf`) as attribute
/// values or inside coordinate / viewBox lists. Word-internal substrings
/// like "dominant-baseline" are deliberately ignored.
func svgHasNoSerializedNaN(_ svg: String) -> Bool {
    let lower = svg.lowercased()
    // Attribute values: `="nan"`, `="-nan"`, `="inf"`, `="-inf"`.
    for needle in ["=\"nan\"", "=\"-nan\"", "=\"inf\"", "=\"-inf\""] {
        if lower.contains(needle) { return false }
    }
    // Inside attribute lists (viewBox, transform, points): bare tokens
    // separated by space, comma, or paren.
    for delim in [" nan ", " -nan ", " inf ", " -inf ", ",nan", ",-nan", ",inf", ",-inf", "(nan", "(-nan", "(inf", "(-inf"] {
        if lower.contains(delim) { return false }
    }
    return true
}
