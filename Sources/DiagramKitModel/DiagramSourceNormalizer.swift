import Foundation

/// Centralized source normalization and statement splitting.
/// Replaces the duplicated splitting logic in `SourcePreprocessing.swift`,
/// `src_index.swift`, and `Parser.swift`.
public enum DiagramSourceNormalizer {

    // MARK: - Line endings

    /// Rewrites CRLF and lone CR line endings to `\n`. Every Mermaid parse
    /// starts from this form (`_parseFrontMatterAndStripped` applies it), so
    /// no parser has to know about `\r`. Note that `"\r\n"` is a single
    /// `Character`, so code that compares characters with `"\n"` or splits
    /// a `String` on `"\n"` never sees a CRLF line break.
    public static func normalizedLineEndings(_ source: String) -> String {
        // Check the bytes: `contains("\r")` would compare Characters and
        // miss every CRLF.
        guard source.utf8.contains(UInt8(ascii: "\r")) else { return source }
        return source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    // MARK: - Inline comments

    /// Returns `line` up to the first `%%` that is not inside a
    /// double-quoted string, trimmed. Upstream lexers only recognise `%%` at
    /// a token boundary, so `E["100%% done"]` keeps its label; a plain
    /// `range(of: "%%")` cut such a line at the label and dropped the rest
    /// of the statement.
    public static func strippingInlineComment(_ line: String) -> String {
        var inQuote = false
        var previousWasPercent = false
        var index = line.startIndex
        while index < line.endIndex {
            let ch = line[index]
            if ch == "\"" {
                inQuote.toggle()
                previousWasPercent = false
            } else if ch == "%", !inQuote {
                if previousWasPercent {
                    let cut = line.index(before: index)
                    return String(line[..<cut]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                previousWasPercent = true
            } else {
                previousWasPercent = false
            }
            index = line.index(after: index)
        }
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Raw lines

    /// Split source into raw lines, no filtering.
    ///
    /// Normalizes every line-terminator variant that a real-world editor or
    /// pipeline might produce — CRLF, lone CR, the Unicode line and
    /// paragraph separators (U+2028 / U+2029), and form feed (U+000C) — to
    /// a single `\n` before splitting.
    public static func rawLines(_ source: String) -> [String] {
        normalizedLineEndings(source)
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
            .replacingOccurrences(of: "\u{000C}", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    // MARK: - Diagram lines

    /// For diagrams where each statement is a newline-separated line
    /// (sequence, class, ER, etc.). Returns non-empty, non-comment lines.
    public static func diagramLines(
        _ source: String
    ) -> [String] {
        return _splitStatements(source, separators: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
    }

    // MARK: - Statements (general)

    /// Split source into statements separated by the given character set.
    /// Handles quote-aware splitting so semicolons/newlines inside strings
    /// are not treated as separators.
    public static func statements(
        _ source: String,
        separators: CharacterSet = CharacterSet(charactersIn: "\n;")
    ) -> [String] {
        return _splitStatements(source, separators: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
    }

    // MARK: - Private implementation

    // MARK: - Joined (multiline-aware)

    /// Join multiline `@{ ... }` metadata blocks before splitting.
    /// Flowchart/state parsers that use metadata blocks should call this
    /// variant; other diagrams can use `statements()` directly.
    public static func joinedStatements(
        _ source: String,
        separators: CharacterSet = CharacterSet(charactersIn: "\n;")
    ) -> [String] {
        let joined = _joinMultiLineBlocks(source)
        return statements(joined, separators: separators)
    }

    // MARK: - Private implementation

    /// Quote-aware statement splitter. Newlines always terminate a statement
    /// (Mermaid lexers never allow quoted strings to span lines). Semicolons are
    /// treated as literal content only inside double-quoted regions; single
    /// quotes are never treated as quote openers.
    private static func _splitStatements(
        _ source: String,
        separators: CharacterSet
    ) -> [String] {
        var parts: [String] = []
        var current = ""
        var inQuote = false
        var isEscaped = false

        for ch in source {
            // `"\r\n"` is one grapheme, so it must be matched explicitly.
            if ch == "\n" || ch == "\r\n" || ch == "\r" {
                // Newline always ends the current statement and resets quote state.
                parts.append(current)
                current = ""
                inQuote = false
                isEscaped = false
                continue
            }

            if inQuote {
                current.append(ch)
                if isEscaped {
                    isEscaped = false
                    continue
                }
                if ch == "\\" {
                    isEscaped = true
                    continue
                }
                if ch == "\"" {
                    inQuote = false
                }
                continue
            }

            if ch == "\"" {
                inQuote = true
                current.append(ch)
                continue
            }

            if ch.unicodeScalars.count == 1,
               let scalar = ch.unicodeScalars.first,
               separators.contains(scalar) {
                parts.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }

        parts.append(current)
        return parts
    }
}

