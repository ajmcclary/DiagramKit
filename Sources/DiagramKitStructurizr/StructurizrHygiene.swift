import Foundation

/// Shared identifier/string hygiene for the Structurizr format target.
/// The exporter's `escape` helper and the alias sanitizer both live here so
/// there is exactly one implementation per transform.
enum StructurizrHygiene {

    /// Escapes a value for emission inside a Structurizr double-quoted
    /// string: backslash and quote are escaped, LF becomes a space, and a
    /// bare CR is dropped.
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")
    }

    /// Returns a parser-safe alias. Matches the StructurizrLexer identifier
    /// grammar: first char letter/underscore; subsequent chars
    /// letter/digit/underscore/dot/slash/colon/hyphen. Everything else
    /// collapses to `_`; an empty alias becomes `"_"`.
    static func sanitizeIdentifier(_ alias: String) -> String {
        guard !alias.isEmpty else { return "_" }
        var out = ""
        var isFirst = true
        for c in alias {
            if isFirst {
                if c.isLetter || c == "_" {
                    out.append(c)
                } else {
                    out.append("_")
                }
                isFirst = false
            } else {
                if c.isLetter || c.isNumber || c == "_" || c == "." || c == "/" || c == ":" || c == "-" {
                    out.append(c)
                } else {
                    out.append("_")
                }
            }
        }
        return out
    }
}
