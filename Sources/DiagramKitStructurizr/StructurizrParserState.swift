import Foundation
import DiagramKitModel
import DiagramKitImport

// MARK: - Parser State

/// Internal parse state for `StructurizrParser`.
struct StructurizrParserState {
    var tokens: [StructurizrToken]
    var pos: Int = 0
    var diagnostics: [DiagramDiagnostic] = []

    mutating func diagnostic(_ message: String, line: Int? = nil) {
        diagnostics.append(.featureDropped(
            .diagramFamilyUnsupported,
            message: message,
            location: DiagramDiagnostic.SourceLocation(line: line)
        ))
    }

    func peek() -> StructurizrToken? {
        pos < tokens.count ? tokens[pos] : nil
    }

    func peekAhead(_ n: Int) -> StructurizrToken? {
        let idx = pos + n
        return idx < tokens.count ? tokens[idx] : nil
    }

    mutating func advance() -> StructurizrToken? {
        guard pos < tokens.count else { return nil }
        let token = tokens[pos]
        pos += 1
        return token
    }

    func identifier(at: Int) -> String? {
        guard at < tokens.count else { return nil }
        switch tokens[at] {
        case .identifier(let s): return s
        default: return nil
        }
    }

    func peekIdentifier() -> String? {
        identifier(at: pos)
    }

    mutating func consumeIdentifier() -> String? {
        guard pos < tokens.count else { return nil }
        switch tokens[pos] {
        case .identifier(let s):
            pos += 1
            return s
        default:
            return nil
        }
    }

    mutating func consumeString() -> String? {
        guard pos < tokens.count else { return nil }
        switch tokens[pos] {
        case .string(let s):
            pos += 1
            return s
        default:
            return nil
        }
    }

    mutating func consumeIf(_ token: StructurizrToken) -> Bool {
        guard pos < tokens.count, tokens[pos] == token else { return false }
        pos += 1
        return true
    }

    // MARK: - Block skipping helpers

    /// Skip tokens until a structural token (close brace, open brace,
    /// or keyword "model"/"views").
    mutating func skipUntilStructuralToken() {
        while let token = peek() {
            switch token {
            case .closeBrace, .openBrace: return
            case .identifier(let word):
                if word == "model" || word == "views" { return }
                _ = advance()
            default:
                _ = advance()
            }
        }
    }

    /// Skip a balanced `{ ... }` block (consumes both braces).
    mutating func skipBlock() {
        guard peek() == .openBrace else { return }
        _ = advance()
        var depth = 1
        while let token = peek(), depth > 0 {
            switch token {
            case .openBrace: depth += 1
            case .closeBrace: depth -= 1
            default: break
            }
            _ = advance()
        }
    }

    // MARK: - Unsupported construct helpers

    /// Skip a `tags` statement and emit diagnostic.
    mutating func skipTags(message: String = "tags statement not yet supported") {
        diagnostic(message)
        _ = advance()
        while consumeString() != nil {}
    }

    /// Skip a `!directive` and emit diagnostic.
    mutating func skipDirective(directive: String) {
        diagnostic("!\(directive) directive not yet supported")
        switch peek() {
        case .identifier, .string, .star:
            _ = advance()
        case .openBrace:
            skipBlock()
        default:
            break
        }
    }
}
