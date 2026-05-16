import Foundation

/// Parses YAML-like frontmatter from Mermaid diagram sources.
/// Extracts key-value pairs from `---` delimited blocks and delegates
/// binding to `FrontmatterBinding` implementations.
public enum FrontmatterDocumentParser {

    /// Parse YAML-like frontmatter lines into a `DiagramFrontmatter`.
    /// Delegates to `_parseYamlFrontmatter` which handles global keys inline
    /// and dispatches diagram-specific config through `FrontmatterBinding`.
    public static func parse(_ lines: [String]) -> DiagramFrontmatter? {
        _parseYamlFrontmatter(lines)
    }

    /// Parse YAML-like frontmatter lines and return flattened key-value
    /// pairs suitable for `FrontmatterBinding.apply(path:value:)`.
    /// Each pair has a dot-separated path (e.g. `"config.sequence.diagramMarginX"`)
    /// and a `FrontmatterValue`.
    ///
    /// Indentation: spaces count as one column each; a leading tab counts
    /// as two columns (matching the 2-space-per-level convention the rest
    /// of the parser assumes). Mixed indent works, tab-only indent works.
    ///
    /// Quoted values: surrounding `"` or `'` are stripped. Inside a
    /// double-quoted value, `\"` and `\\` are unescaped to `"` and `\`.
    /// Single-quoted values are taken literally (YAML single-quote rule).
    ///
    /// Comments: a `#` on its own line is a full-line comment. Inside an
    /// unquoted value, ` #` (whitespace-separated) starts a trailing
    /// comment that is dropped. `#` inside a quoted value is preserved.
    public static func flatten(_ lines: [String]) -> [(path: String, value: FrontmatterValue)] {
        var result: [(String, FrontmatterValue)] = []
        var currentPath: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            // Count indent columns: space = 1, tab = 2.
            var indent = 0
            for ch in line {
                if ch == " " {
                    indent += 1
                } else if ch == "\t" {
                    indent += 2
                } else {
                    break
                }
            }
            let depth = indent / 2
            // Pop back to the correct nesting depth
            while currentPath.count > depth { currentPath.removeLast() }

            // Split on first colon only
            guard let colonIdx = trimmed.firstIndex(of: ":") else { continue }
            var key = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let valuePart = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

            // Strip surrounding quotes from keys (e.g. "Electricity grid" → Electricity grid)
            if (key.hasPrefix("\"") && key.hasSuffix("\"") && key.count >= 2) ||
               (key.hasPrefix("'") && key.hasSuffix("'") && key.count >= 2) {
                key = String(key.dropFirst().dropLast())
            }

            // Nesting keys (no inline value) extend the current path; leaf
            // keys (with a value) should NOT — otherwise the next sibling at
            // the same indent inherits the leaf's name (e.g.
            // `rowIndent: 80` followed by `lineThickness: 3` would emit
            // `config.treeView.rowIndent.lineThickness`).
            if valuePart.isEmpty {
                currentPath.append(key)
                continue
            }

            let unquoted: String
            if valuePart.hasPrefix("\"") && valuePart.hasSuffix("\"") && valuePart.count >= 2 {
                // Double-quoted: unescape `\"` and `\\`.
                let stripped = String(valuePart.dropFirst().dropLast())
                unquoted = stripped
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\\\", with: "\\")
            } else if valuePart.hasPrefix("'") && valuePart.hasSuffix("'") && valuePart.count >= 2 {
                // Single-quoted: literal (YAML single-quote semantics).
                unquoted = String(valuePart.dropFirst().dropLast())
            } else {
                // Unquoted: strip a trailing ` # comment` if present.
                unquoted = Self._stripTrailingComment(valuePart)
            }
            let fullPath = (currentPath + [key]).joined(separator: ".")
            result.append((fullPath, FrontmatterValue(raw: unquoted)))
        }
        return result
    }

    /// Drop ` # …` trailing comments from an unquoted YAML scalar.
    /// Requires the `#` to be whitespace-preceded so values like
    /// `color: #fff` (a hex literal) are preserved.
    private static func _stripTrailingComment(_ value: String) -> String {
        var prev: Character? = nil
        for idx in value.indices {
            let ch = value[idx]
            if ch == "#", let p = prev, p.isWhitespace {
                return String(value[..<idx]).trimmingCharacters(in: .whitespaces)
            }
            prev = ch
        }
        return value
    }
}
