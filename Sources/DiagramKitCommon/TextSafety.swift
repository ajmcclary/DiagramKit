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

// MARK: - Link targets

/// Schemes that never become a link or image target (upstream Mermaid's
/// sanitize-url blocks the same three).
private let _blockedLinkSchemes: Set<String> = ["javascript", "data", "vbscript"]

/// True when `url` may be written as a link or image target in SVG. The
/// check runs at output only: the model and the exported source keep every
/// URL as written (owner ruling: deep links such as `obsidian://` or
/// `vscode://` are ordinary content). Whitespace and control characters are
/// removed and case is folded before the scheme is read, as a browser does
/// when it parses a URL, so `java<TAB>script:` is caught. A URL with no
/// scheme (fragment or relative reference) is allowed.
public func _isSafeLinkURL(_ url: String) -> Bool {
    let squeezed = String(String.UnicodeScalarView(url.unicodeScalars.filter {
        $0.value > 0x20 && $0.value != 0x7F && !$0.properties.isWhitespace
    })).lowercased()
    guard !squeezed.isEmpty else { return false }
    guard let colon = squeezed.firstIndex(of: ":") else { return true }
    if let delimiter = squeezed.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }), delimiter < colon {
        return true // relative reference: the colon is in a path, query or fragment
    }
    return !_blockedLinkSchemes.contains(String(squeezed[..<colon]))
}
