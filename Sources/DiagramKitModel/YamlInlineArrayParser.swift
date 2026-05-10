import Foundation

// MARK: - YAML inline-array parser
//
// Generic helper for `[a, b, "c, d"]`-style frontmatter values.
// Used by binding adapters (e.g. `FrontmatterBinding+Journey`) and
// `init {}` directive consumers (e.g. `src_radar_parser`) to convert
// inline-array string values into `[String]` lists with quote handling.

/// Parse a YAML inline-array string (e.g. `[a, b, "c, d"]`) into a list.
/// Returns `nil` if `value` is not bracketed.
public func _parseYamlStringArray(_ value: String) -> [String]? {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else { return nil }

    let innerStart = trimmed.index(after: trimmed.startIndex)
    let innerEnd = trimmed.index(before: trimmed.endIndex)
    let inner = String(trimmed[innerStart..<innerEnd])
    if inner.trimmingCharacters(in: .whitespaces).isEmpty {
        return []
    }

    var items: [String] = []
    var current = ""
    var inQuote = false
    var quoteChar: Character?
    var isEscaped = false

    for ch in inner {
        if inQuote {
            current.append(ch)
            if isEscaped {
                isEscaped = false
                continue
            }
            if ch == "\\" && quoteChar == "\"" {
                isEscaped = true
                continue
            }
            if ch == quoteChar {
                inQuote = false
                quoteChar = nil
            }
            continue
        }

        if ch == "\"" || ch == "'" {
            inQuote = true
            quoteChar = ch
            current.append(ch)
            continue
        }

        if ch == "," {
            items.append(_unquote(current))
            current = ""
        } else {
            current.append(ch)
        }
    }

    items.append(_unquote(current))
    return items
}
