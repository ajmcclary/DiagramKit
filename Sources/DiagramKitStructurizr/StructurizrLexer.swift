import Foundation

// MARK: - Token types

public enum StructurizrToken: Sendable, Equatable {
    case identifier(String)
    case string(String)
    case openBrace
    case closeBrace
    case equals
    case arrow
    case star
    case bang
}

// MARK: - Lexer

/// Tokenizer for Structurizr DSL source.
///
/// Strips `//` and `#` single-line comments, `/* ... */` block comments.
/// Returns `[StructurizrToken]`.
public struct StructurizrLexer: Sendable {

    public init() {}

    public func tokenize(_ source: String) -> [StructurizrToken] {
        let preprocessed = preprocess(source)
        return tokenizePreprocessed(preprocessed)
    }

    // MARK: - Preprocessing (comment stripping)

    private func preprocess(_ source: String) -> String {
        var result = ""
        var i = source.startIndex
        let end = source.endIndex

        var inString = false
        var escaping = false

        while i < end {
            if inString {
                result.append(source[i])

                if escaping {
                    escaping = false
                } else if source[i] == "\\" {
                    escaping = true
                } else if source[i] == "\"" {
                    inString = false
                }

                i = source.index(after: i)
                continue
            }

            if source[i] == "\"" {
                inString = true
                result.append(source[i])
                i = source.index(after: i)
                continue
            }

            // Block comment: /* ... */
            if source[i] == "/" && source.index(after: i) < end && source[source.index(after: i)] == "*" {
                i = source.index(i, offsetBy: 2)
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
                    i = end
                }
                result.append(" ")
                continue
            }

            // Line comment: // or #
            if (source[i] == "/" && source.index(after: i) < end && source[source.index(after: i)] == "/")
                || source[i] == "#" {
                while i < end && source[i] != "\n" {
                    i = source.index(after: i)
                }
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

    private func tokenizePreprocessed(_ source: String) -> [StructurizrToken] {
        var tokens: [StructurizrToken] = []
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
            c.isLetter || c == "_"
        }

        func isIdentChar(_ c: Character) -> Bool {
            c.isLetter || c.isNumber || c == "_" || c == "." || c == "/" || c == ":" || c == "-"
        }

        func peekChar() -> Character? {
            i < end ? source[i] : nil
        }

        while i < end {
            let c = source[i]

            // Skip whitespace
            if isWhitespace(c) {
                advance()
                continue
            }

            // Punctuation
            switch c {
            case "{":
                tokens.append(.openBrace)
                advance()
                continue
            case "}":
                tokens.append(.closeBrace)
                advance()
                continue
            case "=":
                tokens.append(.equals)
                advance()
                continue
            case "*":
                tokens.append(.star)
                advance()
                continue
            case "!":
                tokens.append(.bang)
                advance()
                continue
            case "-":
                if let next = peekAhead(1), next == ">" {
                    tokens.append(.arrow)
                    advance()
                    advance()
                    continue
                }
                // Lone '-' — fall through to identifier
                var ident = "-"
                advance()
                while i < end, isIdentChar(source[i]) {
                    ident.append(source[i])
                    advance()
                }
                tokens.append(.identifier(ident))
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

            // Unknown character — skip for lenience.
            advance()
        }

        return tokens
    }
}
