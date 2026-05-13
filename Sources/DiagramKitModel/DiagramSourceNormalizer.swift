import Foundation

/// Centralized source normalization and statement splitting.
/// Replaces the duplicated splitting logic in `SourcePreprocessing.swift`,
/// `src_index.swift`, and `Parser.swift`.
public enum DiagramSourceNormalizer {

    // MARK: - Raw lines

    /// Split source into raw lines (CRLF normalized, no filtering).
    public static func rawLines(_ source: String) -> [String] {
        source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
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

    /// Quote-aware statement splitter. Characters in `separators` that appear
    /// inside single- or double-quoted regions are treated as literal content.
    private static func _splitStatements(
        _ source: String,
        separators: CharacterSet
    ) -> [String] {
        var parts: [String] = []
        var current = ""
        var inQuote = false
        var quoteChar: Character?
        var isEscaped = false

        for ch in source {
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

