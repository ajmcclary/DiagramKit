// Metadata parser for @{ ... } blocks in flowcharts
import Foundation

/// Join multiline @{ ... } blocks into single logical lines before line-splitting.
/// Mermaid supports metadata blocks spanning multiple lines, e.g.:
///   A@{ shape: cloud,
///       label: "Data" }
public func _joinMultiLineBlocks(_ source: String) -> String {
    var result = ""
    var depth = 0
    var inBlock = false
    var inQuote = false
    var quoteChar: Character? = nil
    var i = source.startIndex

    while i < source.endIndex {
        let ch = source[i]
        let nextIdx = source.index(after: i)

        if inBlock {
            if ch == "\"" || ch == "'" {
                if !inQuote { inQuote = true; quoteChar = ch }
                else if ch == quoteChar { inQuote = false; quoteChar = nil }
            } else if !inQuote {
                if ch == "{" { depth += 1 }
                else if ch == "}" {
                    depth -= 1
                    if depth == 0 {
                        inBlock = false
                        result.append(ch)
                        i = nextIdx
                        continue
                    }
                }
            }
            if ch == "\n" || ch == "\r" {
                if !inQuote { result.append(" "); i = nextIdx; continue }
            }
            result.append(ch)
        } else {
            if ch == "@" && nextIdx < source.endIndex && source[nextIdx] == "{" {
                inBlock = true
                depth = 0
                result.append(ch)
                i = nextIdx
                continue
            }
            result.append(ch)
        }
        i = nextIdx
    }
    return result
}

/// Parse a metadata block from text starting with "@{".
/// Returns the parsed NodeProperties and the remaining text after the closing "}".
public func _parseMetadataBlock(_ text: String) -> (props: original_src_types.NodeProperties, remaining: String)? {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard t.hasPrefix("@{") else { return nil }

    // Find matching closing brace
    var depth = 0
    var inQuote = false
    var quoteChar: Character? = nil
    var closingIndex: String.Index?

    for (i, ch) in zip(t.indices, t).dropFirst() {
        if ch == "\"" || ch == "'" {
            if !inQuote { inQuote = true; quoteChar = ch }
            else if ch == quoteChar { inQuote = false; quoteChar = nil }
        } else if !inQuote {
            if ch == "{" { depth += 1 }
            else if ch == "}" {
                if depth <= 0 { closingIndex = i; break }
                depth -= 1
                if depth == 0 { closingIndex = i; break }
            }
        }
    }

    guard let endIdx = closingIndex else { return nil }

    let content = String(t[t.index(t.startIndex, offsetBy: 2)..<endIdx])
    let remaining = String(t[t.index(after: endIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)

    var props = original_src_types.NodeProperties()
    let pairs = _splitTopLevelCommas(content)
    for pair in pairs {
        let trimmed = pair.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colonIdx = trimmed.firstIndex(of: ":") else { continue }
        let key = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
        let rawValue = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let value = _unquote(rawValue)

        switch key.lowercased() {
        case "shape":      props.shape = value
        case "label":      props.label = value
        case "icon":       props.icon = value
        case "form":       props.form = value
        case "pos":        props.pos = value
        case "img":        props.img = value
        case "w":          props.w = Double(value)
        case "h":          props.h = Double(value)
        case "constraint": props.constraint = value
        case "animate":    props.animate = (value.lowercased() == "true")
        case "animation":  props.animation = value
        case "curve":      props.curve = value
        default: break
        }
    }

    return (props, remaining)
}

/// Split a string by top-level commas (commas not inside quotes).
private func _splitTopLevelCommas(_ text: String) -> [String] {
    var result: [String] = []
    var current = ""
    var inQuote = false
    var quoteChar: Character? = nil

    for ch in text {
        if ch == "\"" || ch == "'" {
            if !inQuote { inQuote = true; quoteChar = ch }
            else if ch == quoteChar { inQuote = false; quoteChar = nil }
            current.append(ch)
        } else if ch == "," && !inQuote {
            result.append(current)
            current = ""
        } else {
            current.append(ch)
        }
    }
    if !current.isEmpty { result.append(current) }
    return result
}

/// Strip surrounding quotes from a string value.
public func _unquote(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
       (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
        let start = trimmed.index(after: trimmed.startIndex)
        let end = trimmed.index(before: trimmed.endIndex)
        return String(trimmed[start..<end])
    }
    return trimmed
}
