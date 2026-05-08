import Testing
@testable import BeautifulMermaid

@Suite("Treemap Parser")
struct TreemapParserTests {

    @Test("Parses basic treemap with treemap-beta header")
    func basicTreemapBeta() throws {
        let source = """
        treemap-beta
        "Category A"
            "Item A1": 10
            "Item A2": 20
        "Category B"
            "Item B1": 15
            "Item B2": 25
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.nodes.count == 2)
        #expect(result.nodes[0].name == "Category A")
        #expect(result.nodes[0].children?.count == 2)
        #expect(result.nodes[0].children?[0].name == "Item A1")
        #expect(result.nodes[0].children?[0].value == 10)
        #expect(result.nodes[1].name == "Category B")
        #expect(result.nodes[0].children?[1].name == "Item A2")
        #expect(result.nodes[0].children?[1].value == 20)
    }

    @Test("Parses basic treemap with treemap header")
    func basicTreemap() throws {
        let source = """
        treemap
        "Cat"
            "Item": 100
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.nodes.count == 1)
        #expect(result.nodes[0].name == "Cat")
        #expect(result.nodes[0].children?.count == 1)
        #expect(result.nodes[0].children?[0].value == 100)
    }

    @Test("Parses leaf value with comma separator")
    func commaSeparator() throws {
        let source = """
        treemap
        "Root"
          "Child1" , 100
          "Child2" : 200
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.nodes.count == 1)
        #expect(result.nodes[0].children?.count == 2)
        #expect(result.nodes[0].children?[0].name == "Child1")
        #expect(result.nodes[0].children?[0].value == 100)
        #expect(result.nodes[0].children?[1].name == "Child2")
        #expect(result.nodes[0].children?[1].value == 200)
    }

    @Test("Parses single-quoted labels")
    func singleQuotedLabels() throws {
        let source = """
        treemap
        'Category'
            'Item': 50
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.nodes.count == 1)
        #expect(result.nodes[0].name == "Category")
        #expect(result.nodes[0].children?[0].name == "Item")
    }

    @Test("Parses number with comma thousands separator")
    func commaThousands() throws {
        let source = """
        treemap
        "Sales"
            "Q1": 1,234
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.nodes[0].children?[0].value == 1234)
    }

    @Test("Parses title directive")
    func titleDirective() throws {
        let source = """
        treemap
          title Budget Treemap
        "Budget"
            "Item": 10
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.diagramTitle == "Budget Treemap")
    }

    @Test("Parses accTitle directive")
    func accTitleDirective() throws {
        let source = """
        treemap
          accTitle: My Treemap
        "A"
            "B": 10
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.accTitle == "My Treemap")
    }

    @Test("Parses accDescr directive")
    func accDescrDirective() throws {
        let source = """
        treemap
          accDescr: My description
        "A"
            "B": 10
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.accDescr == "My description")
    }

    @Test("Parses multiline accDescr block")
    func multilineAccDescr() throws {
        let source = """
        treemap
          accDescr { My multi
        line description }
        "A"
            "B": 10
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.accDescr == "My multi line description")
    }

    @Test("Parses inline class selectors on sections")
    func sectionInlineClass() throws {
        let source = """
        treemap
        "Category":::cat
            "Item": 10
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.nodes[0].classSelector == "cat")
    }

    @Test("Parses inline class selectors on leaves")
    func leafInlineClass() throws {
        let source = """
        treemap
        "Category"
            "Item": 10:::item
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.nodes[0].children?[0].classSelector == "item")
    }

    @Test("Parses classDef statements")
    func classDefParsing() throws {
        let source = """
        treemap
        classDef myClass fill:#ff0000,stroke:#333;
        "A": 10
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.classDefs.count == 1)
        #expect(result.classDefs[0].className == "myClass")
        #expect(result.classDefs[0].styleText == "fill:#ff0000,stroke:#333")
    }

    @Test("Applies classDef styles to matching sections and leaves")
    func classDefStylesAreApplied() throws {
        let source = """
        treemap
        classDef hot fill:#ff0000,stroke:#333,color:#111;
        "Category":::hot
            "Item": 10:::hot
        """
        let result = try parseTreemapDiagram(source)

        #expect(result.nodes[0].cssCompiledStyles?.contains("fill:#ff0000") == true)
        #expect(result.nodes[0].cssCompiledStyles?.contains("stroke:#333") == true)
        #expect(result.nodes[0].children?[0].cssCompiledStyles?.contains("fill:#ff0000") == true)
    }

    @Test("Applies classDef text styles separately for labels")
    func classDefTextStylesApplied() throws {
        let source = """
        treemap
        classDef hot fill:#ff0000,stroke:#333,color:#111;
        "Category":::hot
            "Item": 10:::hot
        """
        let result = try parseTreemapDiagram(source)

        #expect(result.nodes[0].cssCompiledTextStyles?.contains("color:#111") == true)
        #expect(result.nodes[0].cssCompiledTextStyles?.contains("fill:#ff0000") == true)
        #expect(result.nodes[0].children?[0].cssCompiledTextStyles?.contains("color:#111") == true)
    }

    @Test("Parses comments")
    func comments() throws {
        let source = """
        treemap-beta
        %% This is a comment
        "Category"
            "Item": 10
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.nodes.count == 1)
    }

    @Test("Parses deep hierarchy")
    func deepHierarchy() throws {
        let source = """
        treemap
        "Level 1"
            "Level 2"
                "Level 3"
                    "Leaf": 10
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.nodes[0].children?[0].children?[0].children?[0].name == "Leaf")
        #expect(result.nodes[0].children?[0].children?[0].children?[0].value == 10)
    }

    @Test("Parses multiple top-level nodes")
    func multipleRootNodes() throws {
        let source = """
        treemap
        "Cat A"
            "Item A": 10
        "Cat B"
            "Item B": 20
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.nodes.count == 2)
    }

    @Test("Parses zero value leaf")
    func zeroValue() throws {
        let source = """
        treemap
        "Cat"
            "Item": 0
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.nodes[0].children?[0].value == 0)
    }

    @Test("Parses decimal value")
    func decimalValue() throws {
        let source = """
        treemap
        "Cat"
            "Item": 123.45
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.nodes[0].children?[0].value == 123.45)
    }

    @Test("Throws on truly empty source with no valid content")
    func emptySourceThrows() throws {
        #expect(throws: TreemapParserError.self) {
            _ = try parseTreemapDiagramEmpty()
        }
    }

    @Test("Throws on invalid header")
    func invalidHeaderThrows() throws {
        #expect(throws: TreemapParserError.self) {
            _ = try parseTreemapDiagram("flowchart TD\nA-->B")
        }
    }

    @Test("Throws on malformed treemap statements")
    func malformedStatementsThrow() throws {
        #expect(throws: TreemapParserError.self) {
            _ = try parseTreemapDiagram("treemap\n\"A\" 100")
        }
        #expect(throws: TreemapParserError.self) {
            _ = try parseTreemapDiagram("treemap\n\"A\": nope")
        }
        #expect(throws: TreemapParserError.self) {
            _ = try parseTreemapDiagram("treemap\nnot a valid row")
        }
    }

    @Test("Accept nodes after leaf at same indent as prior section child")
    func nodesAfterLeaf() throws {
        let source = """
        treemap
        "Section"
            "Leaf": 10
            "Another": 20
        """
        let result = try parseTreemapDiagram(source)
        #expect(result.nodes[0].children?.count == 2)
        #expect(result.nodes[0].children?[1].name == "Another")
    }
}

private func parseTreemapDiagram(_ source: String) throws -> TreemapDiagram {
    let normalized = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    let rawLines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    return try parseTreemapDiagram(rawLines, frontmatter: nil)
}

private func parseTreemapDiagramEmpty() throws -> TreemapDiagram {
    try parseTreemapDiagram([], frontmatter: nil)
}
