import Foundation

/// Shared identifier/string hygiene for the Graphviz DOT format target.
/// The per-file `sanitize` / `escape` / `quoted` helpers in the DOT
/// exporters all delegate here so there is exactly one implementation per
/// transform.
enum DOTHygiene {

    /// DOT keywords that cannot appear as bareword node/graph ids.
    static func isReservedKeyword(_ id: String) -> Bool {
        switch id.lowercased() {
        case "node", "edge", "graph", "digraph", "subgraph", "strict":
            return true
        default:
            return false
        }
    }

    /// Rewrites `raw` into a DOT-safe bare identifier (underscore
    /// substitution, leading-digit guard, keyword guard). Collision-aware
    /// emission is a used-id-set concern at the emitter; the DOTTreeView
    /// precedent covers the one format family where names are user-authored.
    static func mangleID(_ raw: String, emptyPlaceholder: String = "node") -> String {
        var out = ""
        for (i, ch) in raw.enumerated() {
            switch ch {
            case "a"..."z", "A"..."Z", "0"..."9", "_":
                if i == 0, ch.isNumber { out.append("_") }
                out.append(ch)
            case " ", "-", ".":
                out.append("_")
            default:
                break
            }
        }
        if out.isEmpty { return emptyPlaceholder }
        // A mangled id can still land on a keyword (`node`, `graph`, …),
        // which DOT would parse as a default-attribute statement.
        if isReservedKeyword(out) {
            return "_\(out)"
        }
        return out
    }

    /// Emits `id` as a DOT ID: bareword when it matches the bareword grammar,
    /// quoted otherwise — keywords always quote.
    static func quoteBarewordID(_ id: String) -> String {
        if isReservedKeyword(id) {
            return quoted(id)
        }
        let allowedFirst = CharacterSet.letters.union(CharacterSet(charactersIn: "_"))
        let allowedTail = allowedFirst.union(.decimalDigits)
        guard let first = id.unicodeScalars.first,
              allowedFirst.contains(first),
              id.unicodeScalars.dropFirst().allSatisfy({ allowedTail.contains($0) }) else {
            return quoted(id)
        }
        return id
    }

    /// Quotes a plain DOT string (escapes backslash and quote).
    static func quoted(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// Quotes a DOT record-shape label. Record line breaks are the `\n`
    /// escape (single backslash) in real Graphviz, so actual newlines are
    /// emitted AS escapes — routing them through `quoted` would double the
    /// backslash and Graphviz would render literal `\n` text.
    static func quotedRecordLabel(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    /// Escapes a value for emission inside a DOT double-quoted string.
    static func escapeString(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }

    /// Collapses a multi-line value onto one line.
    static func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .joined(separator: " ")
    }
}
