import Testing
import DiagramKitStructurizr

@Suite struct StructurizrLexerTests {

    let lexer = StructurizrLexer()

    @Test("tokenize empty source")
    func tokenizeEmptySource() {
        let tokens = lexer.tokenize("")
        #expect(tokens.isEmpty)
    }

    @Test("tokenize identifiers")
    func tokenizeIdentifiers() {
        let tokens = lexer.tokenize("workspace model views")
        let identifiers = tokens.compactMap { token -> String? in
            if case .identifier(let s) = token { return s }
            return nil
        }
        #expect(identifiers == ["workspace", "model", "views"])
    }

    @Test("tokenize strings")
    func tokenizeStrings() {
        let tokens = lexer.tokenize("\"Hello\" \"World\"")
        let strings = tokens.compactMap { token -> String? in
            if case .string(let s) = token { return s }
            return nil
        }
        #expect(strings == ["Hello", "World"])
    }

    @Test("tokenize braces")
    func tokenizeBraces() {
        let tokens = lexer.tokenize("{ }")
        #expect(tokens.count == 2)
        #expect(tokens[0] == .openBrace)
        #expect(tokens[1] == .closeBrace)
    }

    @Test("tokenize equals")
    func tokenizeEquals() {
        let tokens = lexer.tokenize("=")
        #expect(tokens.count == 1)
        #expect(tokens[0] == .equals)
    }

    @Test("tokenize arrow")
    func tokenizeArrow() {
        let tokens = lexer.tokenize("->")
        #expect(tokens.count == 1)
        #expect(tokens[0] == .arrow)
    }

    @Test("tokenize star")
    func tokenizeStar() {
        let tokens = lexer.tokenize("*")
        #expect(tokens.count == 1)
        #expect(tokens[0] == .star)
    }

    @Test("tokenize line comments")
    func tokenizeLineComments() {
        let tokens = lexer.tokenize("// comment\nworkspace")
        let identifiers = tokens.compactMap { token -> String? in
            if case .identifier(let s) = token { return s }
            return nil
        }
        #expect(identifiers == ["workspace"])
    }

    @Test("tokenize block comments")
    func tokenizeBlockComments() {
        let tokens = lexer.tokenize("/* comment */workspace")
        let identifiers = tokens.compactMap { token -> String? in
            if case .identifier(let s) = token { return s }
            return nil
        }
        #expect(identifiers == ["workspace"])
    }

    @Test("tokenize hash comments")
    func tokenizeHashComments() {
        let tokens = lexer.tokenize("# comment\nworkspace")
        let identifiers = tokens.compactMap { token -> String? in
            if case .identifier(let s) = token { return s }
            return nil
        }
        #expect(identifiers == ["workspace"])
    }
}
