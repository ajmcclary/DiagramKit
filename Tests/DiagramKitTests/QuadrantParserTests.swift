import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class QuadrantParserTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n").map(String.init)
    }

    private func single(_ source: String) -> [String] {
        [source]
    }

    // MARK: - Header tests

    func testBareHeader() throws {
        let (chart, _) = try parseQuadrantChart(single("quadrantChart"))
        XCTAssertNil(chart.titleText)
        XCTAssertTrue(chart.points.isEmpty)
    }

    func testHeaderOnlyNoError() throws {
        let (chart, _) = try parseQuadrantChart(single("quadrantChart"))
        XCTAssertEqual(chart.points.count, 0)
    }

    func testInvalidHeader() throws {
        do {
            _ = try parseQuadrantChart(single("garbage"))
            XCTFail("Expected invalidHeader error")
        } catch let error as QuadrantChartParserError {
            guard case .invalidHeader = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testCaseInsensitiveHeader() throws {
        let (chart, _) = try parseQuadrantChart(single("QuadRantChart"))
        XCTAssertTrue(chart.points.isEmpty)
    }

    // MARK: - Title tests

    func testTitle() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\ntitle My Chart"))
        XCTAssertEqual(chart.titleText, "My Chart")
        XCTAssertEqual(chart.diagramTitle, "My Chart")
    }

    // MARK: - Accessibility tests

    func testAccTitle() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\naccTitle: My Title"))
        XCTAssertEqual(chart.accTitle, "My Title")
    }

    func testAccDescrSingleLine() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\naccDescr: My Description"))
        XCTAssertEqual(chart.accDescr, "My Description")
    }

    func testAccDescrMultiline() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\naccDescr {\nLine 1\nLine 2\n}"))
        XCTAssertEqual(chart.accDescr, "Line 1\nLine 2")
    }

    func testAccDescrSingleLineBlockIsCaseInsensitiveAndStripsClosingBrace() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\naCcDeScR { One line description }"))
        XCTAssertEqual(chart.accDescr, "One line description")
    }

    // MARK: - X-axis tests

    func testXAxisBothLabels() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nx-axis Low --> High"))
        XCTAssertEqual(chart.xAxisLeftText, "Low")
        XCTAssertEqual(chart.xAxisRightText, "High")
    }

    func testXAxisLeftOnly() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nx-axis Low"))
        XCTAssertEqual(chart.xAxisLeftText, "Low")
        XCTAssertNil(chart.xAxisRightText)
    }

    func testXAxisTrailingDelimiter() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nx-axis Low -->"))
        XCTAssertEqual(chart.xAxisLeftText, "Low ⟶")
        XCTAssertNil(chart.xAxisRightText)
    }

    func testXAxisQuotedLabels() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nx-axis \"Low Reach\" --> \"High Reach\""))
        XCTAssertEqual(chart.xAxisLeftText, "Low Reach")
        XCTAssertEqual(chart.xAxisRightText, "High Reach")
    }

    func testXAxisCaseInsensitive() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nx-AxIs Low --> High"))
        XCTAssertEqual(chart.xAxisLeftText, "Low")
        XCTAssertEqual(chart.xAxisRightText, "High")
    }

    // MARK: - Y-axis tests

    func testYAxisBothLabels() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\ny-axis Low --> High"))
        XCTAssertEqual(chart.yAxisBottomText, "Low")
        XCTAssertEqual(chart.yAxisTopText, "High")
    }

    func testYAxisBottomOnly() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\ny-axis Low"))
        XCTAssertEqual(chart.yAxisBottomText, "Low")
        XCTAssertNil(chart.yAxisTopText)
    }

    func testYAxisTrailingDelimiter() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\ny-axis Low -->"))
        XCTAssertEqual(chart.yAxisBottomText, "Low ⟶")
        XCTAssertNil(chart.yAxisTopText)
    }

    // MARK: - Quadrant label tests

    func testQuadrant1() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nquadrant-1 Plan"))
        XCTAssertEqual(chart.quadrant1Text, "Plan")
    }

    func testQuadrant2() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nquadrant-2 Do"))
        XCTAssertEqual(chart.quadrant2Text, "Do")
    }

    func testQuadrant3() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nquadrant-3 Delegate"))
        XCTAssertEqual(chart.quadrant3Text, "Delegate")
    }

    func testQuadrant4() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nquadrant-4 Delete"))
        XCTAssertEqual(chart.quadrant4Text, "Delete")
    }

    func testQuadrantCaseInsensitive() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nQuaDrant-1 Plan"))
        XCTAssertEqual(chart.quadrant1Text, "Plan")
    }

    func testQuadrantQuotedLabelMayContainPunctuation() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nquadrant-1 \"Plan (* +=[❤\""))
        XCTAssertEqual(chart.quadrant1Text, "Plan (* +=[❤")
    }

    // MARK: - Point tests

    func testPointBasic() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nCampaign A: [0.3, 0.6]"))
        XCTAssertEqual(chart.points.count, 1)
        XCTAssertEqual(chart.points[0].text, "Campaign A")
        XCTAssertEqual(chart.points[0].x, 0.3)
        XCTAssertEqual(chart.points[0].y, 0.6)
        XCTAssertNil(chart.points[0].className)
    }

    func testPointWithIntCoordinates() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nA: [1, 1]"))
        XCTAssertEqual(chart.points[0].x, 1)
        XCTAssertEqual(chart.points[0].y, 1)
    }

    func testPointEdgeZero() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nA: [0, 0]"))
        XCTAssertEqual(chart.points[0].x, 0)
        XCTAssertEqual(chart.points[0].y, 0)
    }

    func testPointWithClass() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nCampaign A:::myClass: [0.3, 0.6]"))
        XCTAssertEqual(chart.points[0].className, "myClass")
    }

    func testPointWithStyles() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nCampaign A: [0.3, 0.6] radius: 10, color: #ff0000"))
        XCTAssertEqual(chart.points[0].radius, 10)
        XCTAssertEqual(chart.points[0].color, "#ff0000")
    }

    func testPointWithStrokeStyles() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nA: [0.5, 0.5] stroke-color: #00ff00, stroke-width: 3px"))
        XCTAssertEqual(chart.points[0].strokeColor, "#00ff00")
        XCTAssertEqual(chart.points[0].strokeWidth, "3px")
    }

    func testPointClassAndStyles() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nA:::myClass: [0.3, 0.6] radius: 10"))
        XCTAssertEqual(chart.points[0].className, "myClass")
        XCTAssertEqual(chart.points[0].radius, 10)
    }

    func testPointConstructorClass() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nA:::constructor: [0.3, 0.6]"))
        XCTAssertEqual(chart.points[0].className, "constructor")
    }

    func testQuotedPointLabelMayContainBracketAndColon() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\n\"Point1 : (* +=[❤\": [1, 0]"))
        XCTAssertEqual(chart.points[0].text, "Point1 : (* +=[❤")
        XCTAssertEqual(chart.points[0].x, 1)
        XCTAssertEqual(chart.points[0].y, 0)
    }

    func testPointOrderMatchesMermaidPrependOrder() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nA: [0.1, 0.1]\nB: [0.2, 0.2]\nC: [0.3, 0.3]"))
        XCTAssertEqual(chart.points.map(\.text), ["C", "B", "A"])
    }

    func testPointInvalidCoordinateTooLarge() throws {
        do {
            _ = try parseQuadrantChart(lines("quadrantChart\nA: [1.2, 0.5]"))
            XCTFail("Expected error")
        } catch let error as QuadrantChartParserError {
            guard case .invalidPointCoordinate = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testPointInvalidCoordinateNoLeadingZero() throws {
        do {
            _ = try parseQuadrantChart(lines("quadrantChart\nA: [.5, 0.5]"))
            XCTFail("Expected error")
        } catch let error as QuadrantChartParserError {
            guard case .invalidPointCoordinate = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    // MARK: - classDef tests

    func testClassDef() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nclassDef myClass color: #ff0000, radius: 10"))
        XCTAssertEqual(chart.classes["myClass"]?.color, "#ff0000")
        XCTAssertEqual(chart.classes["myClass"]?.radius, 10)
    }

    func testClassDefWithHex() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nclassDef c1 color: #abc, stroke-color: #123456, stroke-width: 5px"))
        XCTAssertEqual(chart.classes["c1"]?.color, "#abc")
        XCTAssertEqual(chart.classes["c1"]?.strokeColor, "#123456")
        XCTAssertEqual(chart.classes["c1"]?.strokeWidth, "5px")
    }

    func testClassDefOverwrite() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nclassDef c1 color: #ff0000\nclassDef c1 color: #00ff00"))
        XCTAssertEqual(chart.classes["c1"]?.color, "#00ff00")
    }

    // MARK: - Style validation tests

    func testInvalidStyleRadius() throws {
        do {
            _ = try parseQuadrantChart(lines("quadrantChart\nA: [0.5, 0.5] radius: abc"))
            XCTFail("Expected error")
        } catch let error as QuadrantChartParserError {
            guard case .invalidStyleValue = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testInvalidStyleColor() throws {
        do {
            _ = try parseQuadrantChart(lines("quadrantChart\nA: [0.5, 0.5] color: zzz"))
            XCTFail("Expected error")
        } catch let error as QuadrantChartParserError {
            guard case .invalidStyleValue = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testInvalidStyleStrokeWidthWithoutPx() throws {
        do {
            _ = try parseQuadrantChart(lines("quadrantChart\nA: [0.5, 0.5] stroke-width: 30"))
            XCTFail("Expected error")
        } catch let error as QuadrantChartParserError {
            guard case .invalidStyleValue = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testInvalidStyleName() throws {
        do {
            _ = try parseQuadrantChart(lines("quadrantChart\nA: [0.5, 0.5] foo: bar"))
            XCTFail("Expected error")
        } catch let error as QuadrantChartParserError {
            guard case .invalidStyleName = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    // MARK: - Full example test

    func testFullExample() throws {
        let source = """
        quadrantChart
            title Reach and engagement of campaigns
            x-axis Low Reach --> High Reach
            y-axis Low Engagement --> High Engagement
            quadrant-1 We should expand
            quadrant-2 Need to promote
            quadrant-3 Re-evaluate
            quadrant-4 May be improved
            Campaign A: [0.3, 0.6]
            Campaign B: [0.45, 0.23]
            Campaign C: [0.57, 0.69]
            Campaign D: [0.78, 0.34]
            Campaign E: [0.40, 0.34]
            Campaign F: [0.35, 0.78]
        """
        let (chart, _) = try parseQuadrantChart(lines(source))
        XCTAssertEqual(chart.titleText, "Reach and engagement of campaigns")
        XCTAssertEqual(chart.xAxisLeftText, "Low Reach")
        XCTAssertEqual(chart.xAxisRightText, "High Reach")
        XCTAssertEqual(chart.yAxisBottomText, "Low Engagement")
        XCTAssertEqual(chart.yAxisTopText, "High Engagement")
        XCTAssertEqual(chart.quadrant1Text, "We should expand")
        XCTAssertEqual(chart.quadrant2Text, "Need to promote")
        XCTAssertEqual(chart.quadrant3Text, "Re-evaluate")
        XCTAssertEqual(chart.quadrant4Text, "May be improved")
        XCTAssertEqual(chart.points.count, 6)
        XCTAssertEqual(chart.points[0].text, "Campaign F")
    }

    // MARK: - Unicode tests

    func testUnicodeCJK() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nx-axis 低覆盖率 --> 高覆盖率"))
        XCTAssertEqual(chart.xAxisLeftText, "低覆盖率")
        XCTAssertEqual(chart.xAxisRightText, "高覆盖率")
    }

    func testUnicodeEmoji() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nquadrant-2 🚀Growth"))
        XCTAssertEqual(chart.quadrant2Text, "🚀Growth")
    }

    func testUnicodeAccented() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\nquadrant-1 catégoría"))
        XCTAssertEqual(chart.quadrant1Text, "catégoría")
    }

    // MARK: - Comments

    func testCommentsIgnored() throws {
        let (chart, _) = try parseQuadrantChart(lines("quadrantChart\n%% this is a comment\nx-axis Low --> High"))
        XCTAssertEqual(chart.xAxisLeftText, "Low")
        XCTAssertEqual(chart.xAxisRightText, "High")
    }

    func testInlineCommentsIgnored() throws {
        let (chart, _) = try parseQuadrantChart(lines("""
        quadrantChart
        x-axis Low --> High %% axis note
        quadrant-1 Plan %% quadrant note
        A: [0.5, 0.5] %% point note
        B: [0.25, 0.75] radius: 10 %% style note
        """))

        XCTAssertEqual(chart.xAxisLeftText, "Low")
        XCTAssertEqual(chart.xAxisRightText, "High")
        XCTAssertEqual(chart.quadrant1Text, "Plan")
        XCTAssertEqual(chart.points.map(\.text), ["B", "A"])
        XCTAssertEqual(chart.points[0].radius, 10)
    }
}
