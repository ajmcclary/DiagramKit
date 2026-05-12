import Testing
@testable import DiagramKitGraphviz
import DiagramKitModel

@Suite struct DOTParserTests {

    // MARK: - Header parsing

    @Test("Parse empty digraph")
    func parseEmptyDigraph() throws {
        let source = "digraph G {}"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        #expect(diags.isEmpty)
        #expect(doc.kind == .digraph)
        #expect(doc.id == "G")
        #expect(doc.statements.isEmpty)
    }

    @Test("Parse empty graph")
    func parseEmptyGraph() throws {
        let source = "graph {}"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        #expect(diags.isEmpty)
        #expect(doc.kind == .graph)
        #expect(doc.id == nil)
        #expect(doc.statements.isEmpty)
    }

    @Test("Parse strict digraph")
    func parseStrictDigraph() throws {
        let source = "strict digraph G {}"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        #expect(doc.strict == true)
        #expect(doc.kind == .digraph)
    }

    @Test("Parse strict graph")
    func parseStrictGraph() throws {
        let source = "strict graph G {}"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        #expect(doc.strict == true)
        #expect(doc.kind == .graph)
    }

    // MARK: - Node statements

    @Test("Parse single node")
    func parseSingleNode() throws {
        let source = "digraph { A; }"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        #expect(doc.statements.count == 1)
        guard case .nodeStatement(let node) = doc.statements[0] else {
            Issue.record("Expected nodeStatement")
            return
        }
        #expect(node.id == "A")
    }

    @Test("Parse node with label")
    func parseNodeWithLabel() throws {
        let source = "digraph { A [label=\"Start\"]; }"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        guard case .nodeStatement(let node) = doc.statements[0] else {
            Issue.record("Expected nodeStatement")
            return
        }
        #expect(node.label == "Start")
    }

    @Test("Parse node with multiple attributes")
    func parseNodeWithMultipleAttrs() throws {
        let source = "digraph { A [label=\"X\", shape=box]; }"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        guard case .nodeStatement(let node) = doc.statements[0] else {
            Issue.record("Expected nodeStatement")
            return
        }
        #expect(node.attributes.count == 2)
    }

    // MARK: - Edge statements

    @Test("Parse directed edge")
    func parseDirectedEdge() throws {
        let source = "digraph { A -> B; }"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        guard case .edgeStatement(let edge) = doc.statements[0] else {
            Issue.record("Expected edgeStatement")
            return
        }
        #expect(edge.source == "A")
        #expect(edge.target == "B")
        #expect(edge.directed == true)
    }

    @Test("Parse undirected edge")
    func parseUndirectedEdge() throws {
        let source = "graph { A -- B; }"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        guard case .edgeStatement(let edge) = doc.statements[0] else {
            Issue.record("Expected edgeStatement")
            return
        }
        #expect(edge.source == "A")
        #expect(edge.target == "B")
        #expect(edge.directed == false)
    }

    @Test("Parse edge with label")
    func parseEdgeWithLabel() throws {
        let source = "digraph { A -> B [label=\"Edge\"]; }"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        guard case .edgeStatement(let edge) = doc.statements[0] else {
            Issue.record("Expected edgeStatement")
            return
        }
        #expect(edge.label == "Edge")
    }

    @Test("Parse chained edge")
    func parseChainedEdge() throws {
        let source = "digraph { A -> B -> C; }"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        let edges = doc.statements.compactMap { stmt -> DOTEdgeStatement? in
            if case .edgeStatement(let e) = stmt { return e }
            return nil
        }
        #expect(edges.count == 2)
        #expect(edges[0].source == "A")
        #expect(edges[0].target == "B")
        #expect(edges[1].source == "B")
        #expect(edges[1].target == "C")
    }

    // MARK: - Attribute statements

    @Test("Parse node default attribute")
    func parseNodeDefaultAttr() throws {
        let source = "digraph { node [shape=box]; A; }"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        let attrStmts = doc.statements.compactMap { stmt -> DOTAttrStatement? in
            if case .attrStatement(let a) = stmt { return a }
            return nil
        }
        #expect(attrStmts.count == 1)
        #expect(attrStmts[0].target == .node)
        #expect(attrStmts[0].attributes.contains { $0.key == "shape" && $0.value == "box" })
    }

    // MARK: - Subgraphs

    @Test("Parse subgraph cluster")
    func parseSubgraphCluster() throws {
        let source = "digraph { subgraph cluster_0 { A; B; } }"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        let subs = doc.statements.compactMap { stmt -> DOTSubgraph? in
            if case .subgraph(let s) = stmt { return s }
            return nil
        }
        #expect(subs.count == 1)
        #expect(subs[0].id == "cluster_0")
        #expect(subs[0].isCluster == true)
        #expect(subs[0].statements.count == 2)
    }

    @Test("Parse anonymous subgraph")
    func parseAnonymousSubgraph() throws {
        let source = "digraph { subgraph { A; } }"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        let subs = doc.statements.compactMap { stmt -> DOTSubgraph? in
            if case .subgraph(let s) = stmt { return s }
            return nil
        }
        #expect(subs.count == 1)
        #expect(subs[0].id == nil)
    }

    // MARK: - Graph-level attributes

    @Test("Parse graph rankdir")
    func parseGraphRankdir() throws {
        let source = "digraph { rankdir=LR; }"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        let graphAttrs = doc.statements.compactMap { stmt -> (String, String)? in
            if case .graphAttr(let k, let v) = stmt { return (k, v) }
            return nil
        }
        #expect(graphAttrs.count == 1)
        #expect(graphAttrs[0].0 == "rankdir")
        #expect(graphAttrs[0].1 == "LR")
    }

    // MARK: - Comments

    @Test("Parse comments")
    func parseComments() throws {
        let source = "digraph { // comment\nA; /* block */\nB; }"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        let nodes = doc.statements.compactMap { stmt -> String? in
            if case .nodeStatement(let node) = stmt { return node.id }
            return nil
        }
        #expect(nodes == ["A", "B"])
    }

    // MARK: - Attribute values

    @Test("Parse unquoted attribute value")
    func parseUnquotedAttrValue() throws {
        let source = "digraph { A [shape=box]; }"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        guard case .nodeStatement(let node) = doc.statements[0] else {
            Issue.record("Expected nodeStatement")
            return
        }
        #expect(node.attributes.contains { $0.key == "shape" && $0.value == "box" })
    }

    // MARK: - Error cases

    @Test("Parse throws on unbalanced braces")
    func parseThrowsOnUnbalancedBraces() throws {
        let source = "digraph { A;"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        #expect(throws: (any Error).self) {
            let _ = try parser.parse(tokens)
        }
    }

    // MARK: - Whitespace resilience

    @Test("Parse whitespace insensitive")
    func parseWhitespaceInsensitive() throws {
        let source = "digraph{A->B}"
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, diags) = try parser.parse(tokens)
        guard case .edgeStatement(let edge) = doc.statements[0] else {
            Issue.record("Expected edgeStatement")
            return
        }
        #expect(edge.source == "A")
        #expect(edge.target == "B")
    }
}
