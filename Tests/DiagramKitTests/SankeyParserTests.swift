import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class SankeyParserTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    func testSankeyHeader() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10"))
        XCTAssertEqual(diagram.links.count, 1)
        XCTAssertEqual(diagram.links[0].value, 10)
    }

    func testSankeyBetaHeader() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey-beta\nA,B,10"))
        XCTAssertEqual(diagram.links.count, 1)
        XCTAssertEqual(diagram.links[0].value, 10)
    }

    func testSankeyHeaderCaseInsensitive() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("Sankey\nA,B,10"))
        XCTAssertEqual(diagram.links.count, 1)
    }

    func testLeadingWhitespaceOnHeader() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("   sankey\nA,B,10"))
        XCTAssertEqual(diagram.links.count, 1)
    }

    func testBasicRecord() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10\nC,D,20"))
        XCTAssertEqual(diagram.links.count, 2)
        XCTAssertEqual(diagram.links[0].value, 10)
        XCTAssertEqual(diagram.links[1].value, 20)
    }

    func testIntegerValue() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nAgriculture,Bio-conversion,124"))
        XCTAssertEqual(diagram.links[0].value, 124)
    }

    func testDecimalValue() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,104.453"))
        XCTAssertEqual(diagram.links[0].value, 104.453)
    }

    func testPrefixedNumericValue() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10px"))
        XCTAssertEqual(diagram.links[0].value, 10)
    }

    func testParseFloatParityValues() throws {
        let source = """
        sankey
        A,B,+.5
        B,C,1e3
        C,D,-2.5e1
        D,E,Infinity
        E,F,abc
        """
        let (diagram, _) = try parseSankeyDiagram(lines(source))
        XCTAssertEqual(diagram.links[0].value, 0.5)
        XCTAssertEqual(diagram.links[1].value, 1000)
        XCTAssertEqual(diagram.links[2].value, -25)
        XCTAssertEqual(diagram.links[3].value, .infinity)
        XCTAssertTrue(diagram.links[4].value.isNaN)
    }

    func testQuotedNewlineIsPreservedInField() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\n\"A\nB\",C,10"))
        XCTAssertNotNil(diagram.nodes.first(where: { $0.id == "A\nB" }))
    }

    func testQuotedField() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\n\"Biofuel imports\",Liquid,35"))
        XCTAssertEqual(diagram.nodes.first(where: { $0.id == "Biofuel imports" })?.id, "Biofuel imports")
        XCTAssertEqual(diagram.links[0].value, 35)
    }

    func testEscapedQuotes() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\n\"\"\"Biomass imports\"\"\",Solid,35"))
        let node = diagram.nodes.first(where: { $0.id == "\"Biomass imports\"" })
        XCTAssertNotNil(node)
    }

    func testCommasInsideQuotedField() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\n\"District heating\",\"Heating and cooling, commercial\",22.505"))
        let target = diagram.nodes.first(where: { $0.id == "Heating and cooling, commercial" })
        XCTAssertNotNil(target)
        XCTAssertEqual(diagram.links[0].value, 22.505)
    }

    func testMixedQuotedAndUnquoted() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nDistrict heating,\"Heating and cooling, homes\",46.184"))
        let target = diagram.nodes.first(where: { $0.id == "Heating and cooling, homes" })
        XCTAssertNotNil(target)
        XCTAssertEqual(diagram.links[0].value, 46.184)
    }

    func testSankeyAsData() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nsankey,target,10"))
        let node = diagram.nodes.first(where: { $0.id == "sankey" })
        XCTAssertNotNil(node)
    }

    func testQuotedSankeyAsData() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\n\"sankey\",target,10"))
        let node = diagram.nodes.first(where: { $0.id == "sankey" })
        XCTAssertNotNil(node)
    }

    func testLeadingTrailingSpacesInFields() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\n    Agricultural waste   ,   Bio-conversion  ,   124.729   "))
        let source = diagram.nodes.first(where: { $0.id == "Agricultural waste" })
        let target = diagram.nodes.first(where: { $0.id == "Bio-conversion" })
        XCTAssertNotNil(source)
        XCTAssertNotNil(target)
        XCTAssertEqual(diagram.links[0].value, 124.729)
    }

    func testEmptyLinesBetweenRecords() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\n\nA,B,10\n\nC,D,20\n\n"))
        XCTAssertEqual(diagram.links.count, 2)
    }

    func testCommentLines() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\n%% This is a comment\nA,B,10\n%% Another comment\nC,D,20"))
        XCTAssertEqual(diagram.links.count, 2)
    }

    func testNodeDeduplication() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10\nA,C,20\nC,D,30"))
        let aNodes = diagram.nodes.filter { $0.id == "A" }
        XCTAssertEqual(aNodes.count, 1)
        XCTAssertEqual(diagram.links.count, 3)
    }

    func testNodeOrderPreserved() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10\nB,C,20\nC,D,30"))
        XCTAssertEqual(diagram.nodes[0].id, "A")
        XCTAssertEqual(diagram.nodes[1].id, "B")
        XCTAssertEqual(diagram.nodes[2].id, "C")
        XCTAssertEqual(diagram.nodes[3].id, "D")
    }

    func testDuplicateLinksNotCollapsed() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10\nA,B,10"))
        XCTAssertEqual(diagram.links.count, 2)
    }

    func testGraphProjection() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10\nB,C,20"))
        let projection = diagram.graphProjection()
        XCTAssertEqual(projection.nodes.count, diagram.nodes.count)
        XCTAssertEqual(projection.links.count, diagram.links.count)
    }

    func testProtoSafety() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\n__proto__,target,10"))
        let node = diagram.nodes.first(where: { $0.id == "__proto__" })
        XCTAssertNotNil(node)
    }

    func testEnergyCsvSubset() throws {
        let source = """
        sankey
        Agricultural 'waste',Bio-conversion,124.729
        Bio-conversion,Liquid,280
        Bio-conversion,Losses,26.862
        Bio-conversion,Solid,280
        """
        let (diagram, _) = try parseSankeyDiagram(lines(source))
        XCTAssertEqual(diagram.links.count, 4)
        XCTAssertGreaterThan(diagram.nodes.count, 0)
    }

    func testMissingHeader() {
        XCTAssertThrowsError(try parseSankeyDiagram(lines("A,B,10"))) { error in
            XCTAssertTrue(error is SankeyParserError)
        }
    }

    func testMalformedRecordTooFewColumns() {
        XCTAssertThrowsError(try parseSankeyDiagram(lines("sankey\nA,B"))) { error in
            XCTAssertTrue(error is SankeyParserError)
        }
    }

    func testMalformedRecordTooManyColumns() {
        XCTAssertThrowsError(try parseSankeyDiagram(lines("sankey\nA,B,C,D"))) { error in
            XCTAssertTrue(error is SankeyParserError)
        }
    }

    func testUnterminatedQuote() {
        XCTAssertThrowsError(try parseSankeyDiagram(lines("sankey\n\"A,B,10"))) { error in
            XCTAssertTrue(error is SankeyParserError)
        }
    }

    func testDefaultConfig() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10"))
        XCTAssertEqual(diagram.config.width, 600)
        XCTAssertEqual(diagram.config.height, 400)
        XCTAssertEqual(diagram.config.linkColor, .gradient)
        XCTAssertEqual(diagram.config.nodeAlignment, .justify)
    }

    func testConfigFromFrontmatter() throws {
        let fm = DiagramFrontmatter.with { $0.perDiagram.sankey.config = SankeyDiagramConfig(
            width: 800,
            height: 600,
            linkColor: .source,
            nodeAlignment: .left,
            showValues: false,
            labelStyle: .outlined
        ) }
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10"), frontmatter: fm)
        XCTAssertEqual(diagram.config.width, 800)
        XCTAssertEqual(diagram.config.height, 600)
        XCTAssertEqual(diagram.config.linkColor, .source)
        XCTAssertEqual(diagram.config.nodeAlignment, .left)
        XCTAssertFalse(diagram.config.showValues)
        XCTAssertEqual(diagram.config.labelStyle, .outlined)
    }

    func testNegativeValuePreserved() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,-10"))
        XCTAssertEqual(diagram.links[0].value, -10)
    }

    func testFullEnergyCsvMatchesMermaid() throws {
        let source = """
        sankey
        Agricultural 'waste',Bio-conversion,124.729
        Bio-conversion,Liquid,0.597
        Bio-conversion,Losses,26.862
        Bio-conversion,Solid,280.322
        Bio-conversion,Gas,81.144
        Biofuel imports,Liquid,35
        Biomass imports,Solid,35
        Coal imports,Coal,11.606
        Coal reserves,Coal,63.965
        Coal,Solid,75.571
        District heating,Industry,10.639
        District heating,Heating and cooling - commercial,22.505
        District heating,Heating and cooling - homes,46.184
        Electricity grid,Over generation / exports,104.453
        Electricity grid,Lighting & appliances - commercial,113.726
        Electricity grid,Lighting & appliances - homes,27.14
        """
        let (diagram, _) = try parseSankeyDiagram(lines(source))
        XCTAssertEqual(diagram.nodes.count, 19)
        XCTAssertEqual(diagram.links.count, 16)
    }

    func testSpecialCharactersFromEnergyCsv() throws {
        let source = """
        sankey
        Agricultural 'waste',Bio-conversion,124.729
        Over generation / exports,Lighting & appliances - commercial,10
        Heating and cooling - homes,Heating and cooling - commercial,20
        """
        let (diagram, _) = try parseSankeyDiagram(lines(source))

        let apostropheNode = diagram.nodes.first(where: { $0.id == "Agricultural 'waste'" })
        XCTAssertNotNil(apostropheNode, "Node with apostrophe should parse")

        let slashNode = diagram.nodes.first(where: { $0.id == "Over generation / exports" })
        XCTAssertNotNil(slashNode, "Node with slash should parse")

        let ampersandNode = diagram.nodes.first(where: { $0.id == "Lighting & appliances - commercial" })
        XCTAssertNotNil(ampersandNode, "Node with ampersand should parse")

        let hyphenNode = diagram.nodes.first(where: { $0.id == "Heating and cooling - homes" })
        XCTAssertNotNil(hyphenNode, "Node with hyphen should parse")

        let hyphenTarget = diagram.nodes.first(where: { $0.id == "Heating and cooling - commercial" })
        XCTAssertNotNil(hyphenTarget, "Target node with hyphen should parse")
    }

    func testNegativeValuesInEnergyCsvSubset() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,-5.5"))
        XCTAssertEqual(diagram.links[0].value, -5.5)
        let positioned = layoutSankeyDiagram(diagram)
        XCTAssertEqual(positioned.links.count, 1)
    }

    func testNodeIdWithHtmlEntities() throws {
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA&amp;B,C,10"))
        let node = diagram.nodes.first(where: { $0.id == "A&amp;B" })
        XCTAssertNotNil(node)
    }
}
