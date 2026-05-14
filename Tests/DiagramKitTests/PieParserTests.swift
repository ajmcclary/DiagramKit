import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class PieParserTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n").map(String.init)
    }

    // MARK: - Header tests

    func testBareHeader() throws {
        let (chart, _) = try parsePieChart(lines("pie"))
        XCTAssertEqual(chart.sections.count, 0)
        XCTAssertFalse(chart.showData)
    }

    func testShowData() throws {
        let (chart, _) = try parsePieChart(lines("pie showData"))
        XCTAssertTrue(chart.showData)
        XCTAssertEqual(chart.sections.count, 0)
    }

    func testWhitespaceHeader() throws {
        let (chart, _) = try parsePieChart(lines("  pie  showData  "))
        XCTAssertTrue(chart.showData)
    }

    func testTabHeader() throws {
        let (chart, _) = try parsePieChart(lines("\tpie\tshowData\t"))
        XCTAssertTrue(chart.showData)
    }

    // MARK: - Section tests

    func testSimpleSections() throws {
        let (chart, _) = try parsePieChart(lines("pie\n\"A\": 100\n\"B\": 50"))
        XCTAssertEqual(chart.sections.count, 2)
        XCTAssertEqual(chart.sections[0].label, "A")
        XCTAssertEqual(chart.sections[0].value, 100)
        XCTAssertEqual(chart.sections[1].label, "B")
        XCTAssertEqual(chart.sections[1].value, 50)
    }

    func testSingleQuotedSections() throws {
        let (chart, _) = try parsePieChart(lines("pie\n'A': 100\n'B': 50"))
        XCTAssertEqual(chart.sections.count, 2)
        XCTAssertEqual(chart.sections[0].label, "A")
        XCTAssertEqual(chart.sections[1].label, "B")
    }

    func testSectionsWithWhitespace() throws {
        let (chart, _) = try parsePieChart(lines("pie\n\"A\"   :   100\n\"B\"\t:\t50"))
        XCTAssertEqual(chart.sections.count, 2)
        XCTAssertEqual(chart.sections[0].value, 100)
        XCTAssertEqual(chart.sections[1].value, 50)
    }

    // MARK: - Title tests

    func testInlineTitle() throws {
        let (chart, _) = try parsePieChart(lines("pie title My Chart\n\"A\": 100"))
        XCTAssertEqual(chart.diagramTitle, "My Chart")
    }

    func testShowDataAndInlineTitle() throws {
        let (chart, _) = try parsePieChart(lines("pie showData title T\n\"A\": 100"))
        XCTAssertTrue(chart.showData)
        XCTAssertEqual(chart.diagramTitle, "T")
    }

    func testSubsequentTitle() throws {
        let (chart, _) = try parsePieChart(lines("pie\ntitle T\n\"A\": 100"))
        XCTAssertEqual(chart.diagramTitle, "T")
    }

    // MARK: - Accessibility tests

    func testInlineAccTitle() throws {
        let (chart, _) = try parsePieChart(lines("pie accTitle: AT\n\"A\": 100"))
        XCTAssertEqual(chart.accTitle, "AT")
    }

    func testInlineAccDescr() throws {
        let (chart, _) = try parsePieChart(lines("pie accDescr: AD\n\"A\": 100"))
        XCTAssertEqual(chart.accDescr, "AD")
    }

    func testSubsequentAccTitle() throws {
        let (chart, _) = try parsePieChart(lines("pie\naccTitle: AT\n\"A\": 100"))
        XCTAssertEqual(chart.accTitle, "AT")
    }

    func testSubsequentAccDescr() throws {
        let (chart, _) = try parsePieChart(lines("pie\naccDescr: AD\n\"A\": 100"))
        XCTAssertEqual(chart.accDescr, "AD")
    }

    func testMultilineAccDescr() throws {
        let (chart, _) = try parsePieChart(lines("pie accDescr { L1\nL2 }\n\"A\": 100"))
        XCTAssertEqual(chart.accDescr, "L1\nL2")
    }

    func testHeaderLineMultilineAccDescrDoesNotSkipFollowingSection() throws {
        let (chart, _) = try parsePieChart(lines("pie accDescr { L1\nL2 }\n\"A\": 100"))
        XCTAssertEqual(chart.accDescr, "L1\nL2")
        XCTAssertEqual(chart.sections.map(\.label), ["A"])
        XCTAssertEqual(chart.sections.first?.value, 100)
    }

    // MARK: - Value tests

    func testDecimalValue() throws {
        let (chart, _) = try parsePieChart(lines("pie\n\"A\": 60.67"))
        XCTAssertEqual(chart.sections[0].value, 60.67)
    }

    func testZeroValue() throws {
        let (chart, _) = try parsePieChart(lines("pie\n\"A\": 0"))
        XCTAssertEqual(chart.sections[0].value, 0)
    }

    func testNegativeValueThrows() {
        XCTAssertThrowsError(try parsePieChart(lines("pie\n\"A\": -5"))) { error in
            guard case PieChartParserError.negativeValue(let label, let value) = error else {
                XCTFail("Expected negativeValue error")
                return
            }
            XCTAssertEqual(label, "A")
            XCTAssertEqual(value, -5)
        }
    }

    func testInvalidNumericLeadingDotThrows() {
        XCTAssertThrowsError(try parsePieChart(lines("pie\n\"A\": .5"))) { error in
            guard case PieChartParserError.invalidValue = error else {
                XCTFail("Expected invalidValue error")
                return
            }
        }
    }

    func testInvalidNumericScientificThrows() {
        XCTAssertThrowsError(try parsePieChart(lines("pie\n\"A\": 1e3"))) { error in
            guard case PieChartParserError.invalidValue = error else {
                XCTFail("Expected invalidValue error")
                return
            }
        }
    }

    func testInvalidNumericPlusSignThrows() {
        XCTAssertThrowsError(try parsePieChart(lines("pie\n\"A\": +5"))) { error in
            guard case PieChartParserError.invalidValue = error else {
                XCTFail("Expected invalidValue error")
                return
            }
        }
    }

    // MARK: - Duplicate labels

    func testDuplicateLabelsFirstWins() throws {
        let (chart, _) = try parsePieChart(lines("pie\n\"A\": 100\n\"A\": 200"))
        XCTAssertEqual(chart.sections.count, 1)
        XCTAssertEqual(chart.sections[0].value, 100)
    }

    // MARK: - Comments

    func testCommentsIgnored() throws {
        let (chart, _) = try parsePieChart(lines("pie\n%% comment\n\"A\": 100"))
        XCTAssertEqual(chart.sections.count, 1)
    }

    // MARK: - Escaped labels

    func testLabelWithEscapedQuotes() throws {
        let (chart, _) = try parsePieChart(lines("pie\n\"He said \\\"hi\\\"\": 50"))
        XCTAssertEqual(chart.sections[0].label, "He said \"hi\"")
    }

    // MARK: - Edge cases

    func testHeaderOnlyNoComment() throws {
        let (chart, _) = try parsePieChart(lines("pie\n%% test"))
        XCTAssertEqual(chart.sections.count, 0)
    }

    func testInvalidHeaderThrows() {
        XCTAssertThrowsError(try parsePieChart(lines("notpie\n\"A\": 100")))
    }

    func testUnknownStatementThrows() {
        XCTAssertThrowsError(try parsePieChart(lines("pie\nnot a pie statement"))) { error in
            guard case PieChartParserError.invalidStatement(let line) = error else {
                XCTFail("Expected invalidStatement error, got \(error)")
                return
            }
            XCTAssertEqual(line, "not a pie statement")
        }
    }

    func testInvalidHeaderRemainderThrows() {
        XCTAssertThrowsError(try parsePieChart(lines("pie nonsense\n\"A\": 100"))) { error in
            guard case PieChartParserError.invalidStatement(let line) = error else {
                XCTFail("Expected invalidStatement error, got \(error)")
                return
            }
            XCTAssertEqual(line, "nonsense")
        }
    }

    func testEmptyLinesThrows() {
        XCTAssertThrowsError(try parsePieChart(lines("")))
    }

    func testFrontmatterOverrides() throws {
        var fm = DiagramFrontmatter()
        fm.pieConfig = PieChartConfig(textPosition: 0.5)
        fm.pieTheme = PieChartThemeConfig(pie1: "#FF0000")
        fm.diagramTitle = "Frontmatter Title"

        let (chart, _) = try parsePieChart(lines("pie\n\"A\": 100"), frontmatter: fm)
        XCTAssertEqual(chart.config.textPosition, 0.5)
        XCTAssertEqual(chart.theme.pie1, "#FF0000")
        XCTAssertEqual(chart.diagramTitle, "Frontmatter Title")
    }

    func testFrontmatterDoesNotOverrideExistingTitle() throws {
        var fm = DiagramFrontmatter()
        fm.diagramTitle = "Frontmatter Title"

        let (chart, _) = try parsePieChart(lines("pie title Source Title\n\"A\": 100"), frontmatter: fm)
        XCTAssertEqual(chart.diagramTitle, "Source Title")
    }
}
