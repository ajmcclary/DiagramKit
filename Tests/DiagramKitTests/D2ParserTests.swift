import Testing
@testable import DiagramKitD2
import DiagramKitModel

@Suite struct D2ParserTests {

    // MARK: - Node parsing

    @Test("Parse single node with label")
    func parseSingleNodeWithLabel() throws {
        let source = "A: Start"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        #expect(doc.statements.count == 1)
        guard case .nodeDefinition(let node) = doc.statements[0] else {
            Issue.record("Expected nodeDefinition")
            return
        }
        #expect(node.id == "A")
        #expect(node.label == "Start")
    }

    @Test("Parse two nodes with labels")
    func parseTwoNodesWithLabels() throws {
        let source = "A: Start\nB: End"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        #expect(doc.statements.count == 2)
    }

    // MARK: - Edge parsing

    @Test("Parse directional edge A -> B")
    func parseDirectionalEdge() throws {
        let source = "A -> B"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        #expect(doc.statements.count == 1)
        guard case .edgeDefinition(let edge) = doc.statements[0] else {
            Issue.record("Expected edgeDefinition")
            return
        }
        #expect(edge.source == "A")
        #expect(edge.target == "B")
        #expect(edge.edgeKind == .directional)
    }

    @Test("Parse bidirectional edge A <-> B")
    func parseBidirectionalEdge() throws {
        let source = "A <-> B"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        guard case .edgeDefinition(let edge) = doc.statements[0] else {
            Issue.record("Expected edgeDefinition")
            return
        }
        #expect(edge.source == "A")
        #expect(edge.target == "B")
        #expect(edge.edgeKind == .bidirectional)
    }

    @Test("Parse undirected edge A -- B")
    func parseUndirectedEdge() throws {
        let source = "A -- B"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        guard case .edgeDefinition(let edge) = doc.statements[0] else {
            Issue.record("Expected edgeDefinition")
            return
        }
        #expect(edge.source == "A")
        #expect(edge.target == "B")
        #expect(edge.edgeKind == .undirected)
    }

    @Test("Parse edge with label")
    func parseEdgeWithLabel() throws {
        let source = "A -> B: hello"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        guard case .edgeDefinition(let edge) = doc.statements[0] else {
            Issue.record("Expected edgeDefinition")
            return
        }
        #expect(edge.label == "hello")
    }

    // MARK: - Container parsing

    @Test("Parse container block with { }")
    func parseContainerBlock() throws {
        let source = "Group {\n  A -> B\n}"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        let opens = doc.statements.filter { if case .containerOpen = $0 { return true }; return false }
        let closes = doc.statements.filter { if case .containerClose = $0 { return true }; return false }
        #expect(opens.count == 1)
        #expect(closes.count == 1)
    }

    @Test("Parse nested containers")
    func parseNestedContainers() throws {
        let source = "Outer {\n  Inner {\n    A -> B\n  }\n}"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        let opens = doc.statements.filter { if case .containerOpen = $0 { return true }; return false }
        let closes = doc.statements.filter { if case .containerClose = $0 { return true }; return false }
        #expect(opens.count == 2)
        #expect(closes.count == 2)
    }

    // MARK: - Dot-chained keys

    @Test("Parse shape: cylinder on node")
    func parseShapeOnNode() throws {
        let source = "A.shape: cylinder"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        guard case .nodeDefinition(let node) = doc.statements[0] else {
            Issue.record("Expected nodeDefinition")
            return
        }
        #expect(node.shape == "cylinder")
    }

    @Test("Parse direction: right at top level")
    func parseDirectionRight() throws {
        let source = "direction: right"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        guard case .nodeDefinition(let node) = doc.statements[0] else {
            Issue.record("Expected nodeDefinition")
            return
        }
        #expect(node.direction == "right")
    }

    @Test("Parse direction: down")
    func parseDirectionDown() throws {
        let source = "direction: down"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
    }

    @Test("Parse dot-chained keys (a.b.c: value)")
    func parseDotChainedKeys() throws {
        let source = "a.b.c: value"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        guard case .nodeDefinition(let node) = doc.statements[0] else {
            Issue.record("Expected nodeDefinition")
            return
        }
        #expect(node.id == "a.b.c")
        #expect(node.label == "value")
    }

    // MARK: - Comments

    @Test("Strip # line comments")
    func stripHashComments() throws {
        let source = "# This is a comment\nA: Start"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        #expect(doc.statements.count == 1)
    }

    @Test("Strip \"\"\" block comments")
    func stripBlockComments() throws {
        let source = "\"\"\"\nblock comment\n\"\"\"\nA: Start"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        #expect(doc.statements.count == 1)
    }

    // MARK: - Empty source

    @Test("Empty source returns empty document")
    func emptySourceReturnsEmptyDocument() throws {
        let source = ""
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        #expect(doc.statements.isEmpty)
    }

    // MARK: - Error handling

    @Test("Unterminated { throws")
    func unterminatedBraceThrows() {
        let source = "Group {"
        let parser = D2Parser()
        #expect(throws: (any Error).self) {
            let _ = try parser.parse(source)
        }
    }

    // MARK: - Multiple edges

    @Test("Parse multiple edges between same nodes")
    func parseMultipleEdgesBetweenSameNodes() throws {
        let source = "A -> B\nA -> C"
        let parser = D2Parser()
        let (doc, diags) = try parser.parse(source)
        #expect(diags.isEmpty)
        let edges = doc.statements.compactMap { stmt -> D2EdgeDefinition? in
            if case .edgeDefinition(let e) = stmt { return e }
            return nil
        }
        #expect(edges.count == 2)
    }

    // MARK: - Unsupported diagnostics

    @Test("Unsupported style.* emits diagnostic")
    func unsupportedStyleEmitsDiagnostic() throws {
        let source = "style.fill: red"
        let parser = D2Parser()
        let (_, diags) = try parser.parse(source)
        #expect(diags.count >= 1)
        #expect(diags[0].severity == .unsupported)
        #expect(diags[0].message.contains("style"))
    }

    @Test("Unsupported vars.* emits diagnostic")
    func unsupportedVarsEmitsDiagnostic() throws {
        let source = "vars.d = 1"
        let parser = D2Parser()
        let (_, diags) = try parser.parse(source)
        #expect(diags.count >= 1)
        #expect(diags[0].message.contains("variable"))
    }

    @Test("Unsupported layers.* emits diagnostic")
    func unsupportedLayersEmitsDiagnostic() throws {
        let source = "layers.a: 1"
        let parser = D2Parser()
        let (_, diags) = try parser.parse(source)
        #expect(diags.count >= 1)
        #expect(diags[0].message.contains("layers"))
    }
}
