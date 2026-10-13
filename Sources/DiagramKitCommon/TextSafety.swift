import Foundation

// MARK: - Guarded unquote

/// Strips a single pair of matching leading/trailing quote characters.
///
/// Whitespace and newlines are trimmed first, then quotes are removed only
/// when the trimmed value has `count >= 2` and the first and last characters
/// are equal and are one of `"` or `'`. This prevents the common trap where
/// `String.removeFirst()` / `removeLast()` are called on a single-character
/// or empty string.
public func _unquote(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 2 else { return trimmed }
    let first = trimmed.first!
    let last = trimmed.last!
    guard first == last, first == "\"" || first == "'" else { return trimmed }
    return String(trimmed.dropFirst().dropLast())
}

/// Variant that strips only the specified quote character after trimming
/// whitespace and newlines.
public func _unquote(_ value: String, quote: Character) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 2, trimmed.first == quote, trimmed.last == quote else {
        return trimmed
    }
    return String(trimmed.dropFirst().dropLast())
}

// MARK: - Safe substring from indices

/// Returns `string[start..<end]` only when `start <= end` and both indices
/// belong to `string`. Returns `nil` for an invalid or inverted range.
public func _safeSubstring(
    _ string: String,
    from start: String.Index,
    to end: String.Index
) -> String? {
    guard start <= end, string.indices.contains(start) || start == string.endIndex,
          string.indices.contains(end) || end == string.endIndex else {
        return nil
    }
    return String(string[start..<end])
}

/// Returns the substring between two independently-located indices, or `nil`
/// if either index is missing or if `lower > upper`.
public func _safeSubstring(
    _ string: String,
    between lower: String.Index?,
    and upper: String.Index?
) -> String? {
    guard let lower, let upper else { return nil }
    return _safeSubstring(string, from: lower, to: upper)
}
