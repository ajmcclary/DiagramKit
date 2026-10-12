import Foundation

/// Extracts `%%{init: ...}%%` directives from Mermaid source lines.
/// Returns structured JSON payloads ready for binding application.
public enum InitDirectiveParser {

    /// Attempt to extract an init directive payload from a single line.
    /// Returns the JSON string inside `%%{init: ...}%%` if present, or `nil`.
    public static func payload(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("%%{"), trimmed.hasSuffix("}%%") else {
            return nil
        }

        let contentStart = trimmed.index(trimmed.startIndex, offsetBy: 3)
        let contentEnd = trimmed.index(trimmed.endIndex, offsetBy: -3)
        let content = String(trimmed[contentStart..<contentEnd])
            .trimmingCharacters(in: .whitespaces)
        guard let colon = content.firstIndex(of: ":") else {
            return nil
        }

        let directiveName = String(content[..<colon])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard directiveName.caseInsensitiveCompare("init") == .orderedSame else {
            return nil
        }

        return String(content[content.index(after: colon)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse the JSON payload into a dictionary. Single-quoted keys/values
    /// outside double-quoted strings are normalized to double quotes before
    /// parsing; apostrophes inside double-quoted values are preserved.
    public static func parseJSON(_ payload: String) -> [String: Any]? {
        let normalized = _normalizeJSONQuotes(payload)
        guard let data = normalized.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private static func _normalizeJSONQuotes(_ payload: String) -> String {
        var result = ""
        var inDoubleQuote = false
        var isEscaped = false
        for ch in payload {
            if isEscaped {
                result.append(ch)
                isEscaped = false
                continue
            }
            if ch == "\\" {
                result.append(ch)
                isEscaped = true
                continue
            }
            if ch == "\"" {
                inDoubleQuote.toggle()
                result.append(ch)
                continue
            }
            if ch == "'", !inDoubleQuote {
                result.append("\"")
                continue
            }
            result.append(ch)
        }
        return result
    }

    /// Parse and convert an init directive payload into `FrontmatterValue`
    /// entries keyed by their flattened path (e.g. `"config.sequence.diagramMarginX"`).
    public static func flatten(
        _ object: [String: Any],
        prefix: String = ""
    ) -> [(path: String, value: FrontmatterValue)] {
        var result: [(String, FrontmatterValue)] = []
        for (key, value) in object {
            let fullPath = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let nested = value as? [String: Any] {
                result.append(contentsOf: flatten(nested, prefix: fullPath))
            } else {
                let rawValue: String
                if let s = value as? String {
                    rawValue = s
                } else if let b = value as? Bool {
                    rawValue = b ? "true" : "false"
                } else if let n = value as? NSNumber {
                    rawValue = n.stringValue
                } else {
                    rawValue = "\(value)"
                }
                result.append((fullPath, FrontmatterValue(raw: rawValue)))
            }
        }
        return result
    }
}
