import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("Venn Parser")
struct VennParserTests {

    @Test("Parses minimal two-set venn-beta diagram")
    func minimalTwoSet() throws {
        let lines = ["venn-beta", "  set A", "  set B", "  union A,B"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.areas.count == 3)
        #expect(result.areas[0].sets == ["A"])
        #expect(result.areas[0].size == 10.0)
        #expect(result.areas[1].sets == ["B"])
        #expect(result.areas[2].sets == ["A", "B"])
        #expect(result.areas[2].size == 2.5)
    }

    @Test("Parses title statement")
    func titleStatement() throws {
        let lines = ["venn-beta", "  title \"My Title\"", "  set A", "  set B", "  union A,B"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.diagramTitle == "My Title")
    }

    @Test("Parses bracket labels")
    func bracketLabels() throws {
        let lines = ["venn-beta", "  set Frontend[\"Frontend Team\"]", "  set Backend[\"Backend Team\"]", "  union Frontend,Backend[\"Shared\"]"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.areas[0].label == "Frontend Team")
        #expect(result.areas[1].label == "Backend Team")
        #expect(result.areas[2].label == "Shared")
    }

    @Test("Parses quoted identifiers")
    func quotedIdentifiers() throws {
        let lines = ["venn-beta", "  set \"Alpha Team\"", "  set \"Beta Team\"", "  union \"Alpha Team\",\"Beta Team\""]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.areas[0].sets == ["Alpha Team"])
        #expect(result.areas[1].sets == ["Beta Team"])
        #expect(result.areas[2].sets == ["Alpha Team", "Beta Team"])
    }

    @Test("Parses explicit sizes")
    func explicitSizes() throws {
        let lines = ["venn-beta", "  set A:20", "  set B:12", "  union A,B:5.3"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.areas[0].size == 20.0)
        #expect(result.areas[1].size == 12.0)
        #expect(result.areas[2].size == 5.3)
    }

    @Test("Parses decimal sizes")
    func decimalSizes() throws {
        let lines = ["venn-beta", "  set A:.5", "  set B:1.5", "  union A,B:.25"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.areas[0].size == 0.5)
        #expect(result.areas[1].size == 1.5)
        #expect(result.areas[2].size == 0.25)
    }

    @Test("Parses three sets with all intersections")
    func threeSetAllIntersections() throws {
        let lines = ["venn-beta", "  set A", "  set B", "  set C", "  union A,B", "  union B,C", "  union A,C", "  union A,B,C"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.areas.count == 7)
        #expect(result.areas[3].sets == ["A", "B"])
        #expect(result.areas[4].sets == ["B", "C"])
        #expect(result.areas[5].sets == ["A", "C"])
        #expect(result.areas[6].sets == ["A", "B", "C"])
    }

    @Test("Parses indented text nodes")
    func indentedTextNodes() throws {
        let lines = ["venn-beta", "  set A", "  set B", "  union A,B", "    text AB1[\"Shared\"]"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.textNodes.count == 1)
        #expect(result.textNodes[0].id == "AB1")
        #expect(result.textNodes[0].label == "Shared")
        #expect(result.textNodes[0].sets == ["A", "B"])
    }

    @Test("Parses indented text after set")
    func indentedTextAfterSet() throws {
        let lines = ["venn-beta", "  set A[\"Alpha\"]", "    text A1[\"A child\"]", "  set B[\"Beta\"]", "    text B1[\"B child\"]"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.textNodes.count == 2)
        #expect(result.textNodes[0].id == "A1")
        #expect(result.textNodes[0].sets == ["A"])
        #expect(result.textNodes[1].id == "B1")
        #expect(result.textNodes[1].sets == ["B"])
    }

    @Test("Parses style statement with hex color")
    func styleHexColor() throws {
        let lines = ["venn-beta", "  set A", "  set B", "  union A,B", "  style A fill:#ff6b6b, color:#333"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.styleEntries.count == 1)
        #expect(result.styleEntries[0].targets == ["A"])
        #expect(result.styleEntries[0].styles["fill"] == "#ff6b6b")
        #expect(result.styleEntries[0].styles["color"] == "#333")
    }

    @Test("Parses style with dashed keys")
    func styleDashedKeys() throws {
        let lines = ["venn-beta", "  set A", "  set B", "  style A,B stroke-width:2, fill-opacity:0.5"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.styleEntries.count == 1)
        #expect(result.styleEntries[0].styles["stroke-width"] == "2")
        #expect(result.styleEntries[0].styles["fill-opacity"] == "0.5")
    }

    @Test("Parses style with rgba")
    func styleRgba() throws {
        let lines = ["venn-beta", "  set A", "  set B", "  style A,B fill:rgba(255, 0, 128, 0.5)"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.styleEntries[0].styles["fill"] == "rgba(255, 0, 128, 0.5)")
    }

    @Test("Skips blank lines and comments")
    func skipsBlankLinesAndComments() throws {
        let lines = ["", "%% A comment", "", "venn-beta", "  %% another comment", "  set A", "", "  set B", "  union A,B", "%% trailing"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.areas.count == 3)
    }

    @Test("Parses with leading blank lines")
    func leadingBlankLines() throws {
        let lines = ["", "", "", "venn-beta", "  set A", "  set B", "  union A,B"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.areas.count == 3)
    }

    @Test("Parses explicit top-level text target")
    func explicitTextTarget() throws {
        let lines = ["venn-beta", "  set A", "  set B", "  union A,B", "  text A,B AB1[\"Shared\"]"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.textNodes.count == 1)
        #expect(result.textNodes[0].id == "AB1")
        #expect(result.textNodes[0].sets == ["A", "B"])
    }

    @Test("Parses explicit single-set text target")
    func explicitSingleTextTarget() throws {
        let lines = ["venn-beta", "set A", "text A A1[\"Alpha item\"]"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.textNodes.count == 1)
        #expect(result.textNodes[0].sets == ["A"])
        #expect(result.textNodes[0].id == "A1")
        #expect(result.textNodes[0].label == "Alpha item")
    }

    @Test("Parses numeric text node id")
    func numericTextNodeId() throws {
        let lines = ["venn-beta", "  set A", "    text 123[\"Numbered\"]"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.textNodes.count == 1)
        #expect(result.textNodes[0].id == "123")
        #expect(result.textNodes[0].label == "Numbered")
    }

    @Test("Default size for single set is 10")
    func defaultSingleSetSize() throws {
        let lines = ["venn-beta", "  set A"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.areas[0].size == 10)
    }

    @Test("Default size for two-set union is 2.5")
    func defaultTwoSetUnionSize() throws {
        let lines = ["venn-beta", "  set A", "  set B", "  union A,B"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.areas[2].size == 2.5)
    }

    @Test("Default size for three-set union is 10/9")
    func defaultThreeSetUnionSize() throws {
        let lines = ["venn-beta", "  set A", "  set B", "  set C", "  union A,B,C"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.areas[3].size == 10.0 / 9.0)
    }

    @Test("Sorted set keys from union B,A")
    func sortedSetKeys() throws {
        let lines = ["venn-beta", "  set A", "  set B", "  union B,A"]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.areas[2].sets == ["A", "B"])
    }

    @Test("Quoted identifier normalization strips quotes")
    func identifierNormalization() throws {
        let lines = ["venn-beta", "  set \"Alpha\"", "  set \"Beta\"", "  union \"Alpha\",\"Beta\""]
        let (result, _) = try parseVennDiagram(lines)
        #expect(result.areas[0].sets == ["Alpha"])
        #expect(result.areas[1].sets == ["Beta"])
        #expect(result.areas[2].sets == ["Alpha", "Beta"])
    }

    @Test("Throws on empty source")
    func emptySourceThrows() {
        #expect(throws: VennParserError.self) {
            try parseVennDiagram([])
        }
    }

    @Test("Throws on missing venn-beta header")
    func missingHeaderThrows() {
        #expect(throws: VennParserError.self) {
            try parseVennDiagram(["set A"])
        }
    }

    @Test("Throws on union with single identifier")
    func unionSingleIdThrows() {
        let lines = ["venn-beta", "  set A", "  union A"]
        #expect(throws: VennParserError.self) {
            try parseVennDiagram(lines)
        }
    }

    @Test("Throws on union with unknown identifier")
    func unionUnknownIdThrows() {
        let lines = ["venn-beta", "  set A", "  union A,B"]
        #expect(throws: VennParserError.self) {
            try parseVennDiagram(lines)
        }
    }

    @Test("Throws on indented text before set")
    func indentedTextBeforeSetThrows() {
        let lines = ["venn-beta", "    text X"]
        #expect(throws: VennParserError.self) {
            try parseVennDiagram(lines)
        }
    }

    @Test("Throws on malformed style")
    func malformedStyleThrows() {
        let lines = ["venn-beta", "  set A", "  style A fill"]
        #expect(throws: VennParserError.self) {
            try parseVennDiagram(lines)
        }
    }
}
