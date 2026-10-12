import Foundation

// MARK: - Safe numeric conversion

/// Converts a `Double` to `Int` only when the value is finite and within a
/// safe magnitude, truncating toward zero exactly like `Int(Double)`.
/// Returns `nil` otherwise.
///
/// This is the shared guard for every `Int(Double)` site that consumes
/// user-provided diagram numbers (pie values, autonumber offsets,
/// frontmatter dimensions, coordinates, etc.). The `1e15` ceiling is well
/// below `Int.max` but above any reasonable diagram coordinate; it also
/// avoids the absorption-by-rounding region where `v + 1 == v`.
public func _safeInt(_ value: Double) -> Int? {
    guard value.isFinite, abs(value) < 1e15 else {
        return nil
    }
    return Int(value)
}

/// Strict variant of `_safeInt` that additionally requires the value to be
/// mathematically an integer. Use at sites whose original code was an
/// explicit `value == value.rounded()` check (integer-only formatting).
public func _safeIntegralInt(_ value: Double) -> Int? {
    guard value.isFinite, abs(value) < 1e15, value == value.rounded() else {
        return nil
    }
    return Int(value)
}

/// `Int64` variant of `_safeInt`. Used where the downstream API is `Int64`
/// (e.g. packet-bitfield widths, treemap comma formatting).
public func _safeInt64(_ value: Double) -> Int64? {
    guard value.isFinite, abs(value) < 1e15 else {
        return nil
    }
    return Int64(value)
}

/// Convenience that returns `defaultValue` when `_safeInt` would return `nil`.
public func _safeInt(_ value: Double, default defaultValue: Int) -> Int {
    _safeInt(value) ?? defaultValue
}

/// Convenience that returns `defaultValue` when `_safeInt64` would return `nil`.
public func _safeInt64(_ value: Double, default defaultValue: Int64) -> Int64 {
    _safeInt64(value) ?? defaultValue
}

/// Clamp a frontmatter/config double to an integer range, falling back to
/// `defaultValue` when the input is non-finite or outside the range.
///
/// Use this at bind time for any numeric setting that must be positive or
/// otherwise bounded (e.g. `gantt.numberSectionStyles >= 1`).
public func _clampedInt(
    _ value: Double,
    min: Int,
    max: Int,
    default defaultValue: Int
) -> Int {
    guard let v = _safeInt(value) else { return defaultValue }
    if v < min { return min }
    if v > max { return max }
    return v
}

// MARK: - SVG number formatting

/// Formats a `Double` for SVG attribute/text output.
///
/// Behaviour matches the existing per-family copy-pasted helpers
/// (`src_xychart_renderer._r`, `src_quadrant_renderer._qR`,
/// `src_sankey_renderer._sankeyFmt`, `src_xychart_layout._formatTickValue`):
///
/// - Non-finite values render as `"0"`.
/// - Values within `_safeInt` range that are integer-like after rounding to
///   one decimal place render as an integer string.
/// - Everything else renders with one fractional digit.
public func _svgNum(_ value: Double) -> String {
    let rounded = (value * 10).rounded() / 10
    if rounded.isFinite, abs(rounded) < 1e15, rounded == rounded.rounded() {
        return String(Int(rounded))
    }
    if !rounded.isFinite { return "0" }
    return String(format: "%.1f", rounded)
}
