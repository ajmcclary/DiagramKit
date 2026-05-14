import Testing
@testable import DiagramKitGraphviz
import DiagramKitModel
import DiagramKitImport
@testable import DiagramKit

@Suite struct DOTLexerHTMLLabelTests {

    // MARK: - Lexer tokenization

    @Test("Lexer emits htmlString for simple <…> attribute value")
    func lexerSimpleHTML() throws {
        let tokens = try DOTLexer().tokenize("digraph G { a [ label=<plain> ] }")
        #expect(tokens.contains { token in
            if case .htmlString(let s) = token { return s == "<plain>" }
            return false
        })
    }

    @Test("Lexer balances nested angle brackets in HTML labels")
    func lexerNestedHTML() throws {
        let source = "digraph G { a [ label=<<TABLE><TR><TD>X</TD></TR></TABLE>> ] }"
        let tokens = try DOTLexer().tokenize(source)
        #expect(tokens.contains { token in
            if case .htmlString(let s) = token {
                return s == "<<TABLE><TR><TD>X</TD></TR></TABLE>>"
            }
            return false
        })
    }

    @Test("Lexer does not enter HTML mode inside quoted strings")
    func lexerQuotedStringWinsOverHTML() throws {
        let tokens = try DOTLexer().tokenize("digraph G { a [ label=\"<not html>\" ] }")
        #expect(tokens.contains { token in
            if case .string(let s) = token { return s == "<not html>" }
            return false
        })
        #expect(!tokens.contains { token in
            if case .htmlString = token { return true }
            return false
        })
    }

    // MARK: - Parser threading + DOTMapper diagnostic revival

    @Test("HTML-label attribute value reaches DOTMapper as diagnostic")
    func htmlLabelEmitsMapperDiagnostic() throws {
        let source = "digraph G { a [ label=<<TABLE><TR><TD>X</TD></TR></TABLE>> ] }"
        let importer = GraphvizImporter()
        let result = try importer.parse(source)
        #expect(result.diagnostics.contains { d in
            d.severity == .unsupported
                && d.message.contains("HTML-like label on node 'a'")
        })
    }

    @Test("HTML-label fallback renders node identifier as label")
    func htmlLabelFallsBackToNodeID() throws {
        let source = "digraph G { mynode [ label=<<B>fancy</B>> ] }"
        let importer = GraphvizImporter()
        let result = try importer.parse(source)
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("expected flowchart payload"); return
        }
        let node = try #require(graph.nodesInOrder.first { $0.id == "mynode" })
        #expect(node.node.label == "mynode")
    }

    @Test("HTML-label does not consume rest of attribute list")
    func htmlLabelDoesNotEatNeighborAttributes() throws {
        let source = "digraph G { a [ label=<<B>x</B>>, shape=cylinder ] }"
        let importer = GraphvizImporter()
        let result = try importer.parse(source)
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("expected flowchart payload"); return
        }
        let node = try #require(graph.nodesInOrder.first { $0.id == "a" })
        // The cylinder attribute should still register — pre-fix, the lexer
        // emitted .unsupported tokens for the angle brackets and the parser
        // dropped the remaining attribute list.
        #expect(node.node.shape == .cylinder)
    }
}
