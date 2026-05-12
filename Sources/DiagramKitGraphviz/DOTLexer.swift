import Foundation

// MARK: - Token types

public enum DOTToken: Sendable, Equatable {
    case identifier(String)          // `A`, `graph`, `digraph`, `shape`, etc.
    case string(String)              // quoted string, quotes stripped
    case openBrace                   // `{`
    case closeBrace                  // `}`
    case openBracket                 // `[`
    case closeBracket                // `]`
    case semicolon                   // `;`
    case equals                      // `=`
    case comma                       // `,`
    case directedEdge                // `->`
    case undirectedEdge              // `--`
}

// MARK: - Lexer

/// Tokenizes raw DOT source into a stream of `DOTToken` values.
///
/// Strips `//` single-line comments, `/* ... */` block comments,
/// and `#` line comments. Identifiers and quoted strings are
/// returned with quotes stripped.
public struct DOTLexer {

    public init() {}

    // MARK: - Public entry point

    public func tokenize(_ source: String) throws -> [DOTToken] {
        let preprocessed = preprocess(source)
        return tokenizePreprocessed(preprocessed)
    }

    // MARK: - Preprocessing (comment stripping)

    private func preprocess(_ source: String) -> String {
        var result = ""
        var i = source.startIndex
        let end = source.endIndex

        while i < end {
            // Block comment: /* ... */
            if source[i] == "/" && source.index(after: i) < end && source[source.index(after: i)] == "*" {
                i = source.index(i, offsetBy: 2)
                // Scan until */
                var foundClose = false
                while i < end {
                    if source[i] == "*" && source.index(after: i) < end && source[source.index(after: i)] == "/" {
                        i = source.index(i, offsetBy: 2)
                        foundClose = true
                        break
                    }
                    i = source.index(after: i)
                }
                if !foundClose {
                    // Unterminated block comment — consume rest
                    i = end
                }
                continue
            }

            // Line comment: // or #
            if (source[i] == "/" && source.index(after: i) < end && source[source.index(after: i)] == "/")
                || source[i] == "#" {
                // Skip to end of line
                while i < end && source[i] != "\n" {
                    i = source.index(after: i)
                }
                // Include the newline
                if i < end {
                    result.append(source[i])
                    i = source.index(after: i)
                }
                continue
            }

            result.append(source[i])
            i = source.index(after: i)
        }

        return result
    }

    // MARK: - Tokenization

    private func tokenizePreprocessed(_ source: String) -> [DOTToken] {
        var tokens: [DOTToken] = []
        var i = source.startIndex
        let end = source.endIndex

        func peek() -> Character? {
            i < end ? source[i] : nil
        }

        func peekAhead(_ n: Int) -> Character? {
            var idx = i
            for _ in 0..<n {
                if idx >= end { return nil }
                idx = source.index(after: idx)
            }
            return idx < end ? source[idx] : nil
        }

        func advance() {
            if i < end { i = source.index(after: i) }
        }

        func isWhitespace(_ c: Character) -> Bool {
            c == " " || c == "\t" || c == "\n" || c == "\r"
        }

        func isIdentStart(_ c: Character) -> Bool {
            c.isLetter || c == "_" || c == "."
        }

        func isIdentChar(_ c: Character) -> Bool {
            c.isLetter || c.isNumber || c == "_" || c == "."
        }

        while i < end {
            let c = source[i]

            // Skip whitespace
            if isWhitespace(c) {
                advance()
                continue
            }

            // Punctuation / operators
            switch c {
            case "{":
                tokens.append(.openBrace)
                advance()
                continue
            case "}":
                tokens.append(.closeBrace)
                advance()
                continue
            case "[":
                tokens.append(.openBracket)
                advance()
                continue
            case "]":
                tokens.append(.closeBracket)
                advance()
                continue
            case ";":
                tokens.append(.semicolon)
                advance()
                continue
            case ",":
                tokens.append(.comma)
                advance()
                continue
            case "=":
                tokens.append(.equals)
                advance()
                continue
            case "-":
                if let next = peekAhead(1), next == ">" {
                    tokens.append(.directedEdge)
                    advance() // -
                    advance() // >
                    continue
                } else if let next = peekAhead(1), next == "-" {
                    tokens.append(.undirectedEdge)
                    advance() // -
                    advance() // -
                    continue
                }
                // Lone '-' — treat as identifier for now (lenient)
                tokens.append(.identifier("-"))
                advance()
                continue
            default:
                break
            }

            // Quoted string
            if c == "\"" {
                var value = ""
                advance() // opening quote
                loop: while i < end {
                    let ch = source[i]
                    if ch == "\\" {
                        advance()
                        if i < end {
                            let escaped = source[i]
                            switch escaped {
                            case "n": value.append("\n")
                            case "t": value.append("\t")
                            case "r": value.append("\r")
                            case "\"": value.append("\"")
                            case "\\": value.append("\\")
                            default: value.append(escaped)
                            }
                            advance()
                        }
                    } else if ch == "\"" {
                        advance() // closing quote
                        break loop
                    } else {
                        value.append(ch)
                        advance()
                    }
                }
                tokens.append(.string(value))
                continue
            }

            // Identifier
            if isIdentStart(c) {
                var ident = ""
                while i < end, isIdentChar(source[i]) {
                    ident.append(source[i])
                    advance()
                }
                tokens.append(.identifier(ident))
                continue
            }

            // Unknown character — skip (lenient)
            advance()
        }

        return tokens
    }
}
