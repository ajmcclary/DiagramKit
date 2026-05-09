import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

final class XYChartParserTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n").map(String.init)
    }

    // MARK: - Header tests

    func test_validBareHeader() throws {
        let source = "xychart\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.series.count, 1)
        XCTAssertEqual(chart.series[0].type, .line)
        XCTAssertEqual(chart.series[0].data, [1, 2, 3])
    }

    func test_invalidHeader_xychart1_throws() {
        let source = "xychart-1"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.invalidHeader = error else {
                XCTFail("Expected invalidHeader, got \(error)")
                return
            }
        }
    }

    func test_invalidOrientation_abc_throws() {
        let source = "xychart abc\nline [1,2]"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.invalidOrientation = error else {
                XCTFail("Expected invalidOrientation, got \(error)")
                return
            }
        }
    }

    // MARK: - Title tests

    func test_title_unquoted() throws {
        let source = "xychart\ntitle oneLinertitle\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.title, "oneLinertitle")
        XCTAssertEqual(chart.titleText?.text, "oneLinertitle")
    }

    func test_title_quoted() throws {
        let source = "xychart\ntitle \"This is a title\"\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.title, "This is a title")
        XCTAssertEqual(chart.titleText?.text, "This is a title")
    }

    func test_title_markdownPreservesKind() throws {
        let source = "xychart\ntitle \"`**Sales**`\"\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.title, "**Sales**")
        XCTAssertEqual(chart.titleText?.kind, .markdown)
    }

    // MARK: - Orientation tests

    func test_orientation_vertical() throws {
        let source = "xychart vertical\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertFalse(chart.horizontal)
        XCTAssertTrue(chart.explicitVertical)
        XCTAssertFalse(chart.explicitHorizontal)
    }

    func test_orientation_horizontal() throws {
        let source = "xychart horizontal\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertTrue(chart.horizontal)
        XCTAssertTrue(chart.explicitHorizontal)
        XCTAssertFalse(chart.explicitVertical)
    }

    // MARK: - X-axis tests

    func test_xAxis_titleOnly() throws {
        let source = "xychart\nx-axis xAxisName\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.xAxis.title, "xAxisName")
        XCTAssertEqual(chart.xAxis.titleText?.text, "xAxisName")
        XCTAssertTrue(chart.xAxis.hasSetAxis)
        XCTAssertEqual(chart.xAxis.kind, .band)
    }

    func test_xAxis_titleOnly_quoted() throws {
        let source = "xychart\nx-axis \"x Axis Name\"\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.xAxis.title, "x Axis Name")
        XCTAssertEqual(chart.xAxis.titleText?.text, "x Axis Name")
    }

    func test_xAxis_range() throws {
        let source = "xychart\nx-axis 0 --> 100\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.xAxis.kind, .linear)
        XCTAssertEqual(chart.xAxis.range?.min, 0)
        XCTAssertEqual(chart.xAxis.range?.max, 100)
        XCTAssertTrue(chart.xAxis.hasSetAxis)
    }

    func test_xAxis_range_withTitle() throws {
        let source = "xychart\nx-axis \"Title\" 0 --> 100\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.xAxis.title, "Title")
        XCTAssertEqual(chart.xAxis.kind, .linear)
        XCTAssertEqual(chart.xAxis.range?.min, 0)
        XCTAssertEqual(chart.xAxis.range?.max, 100)
    }

    func test_xAxis_range_invalidNumber_throws() {
        let source = "xychart\nx-axis aaa --> 33"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.nonNumericData = error else {
                XCTFail("Expected nonNumericData, got \(error)")
                return
            }
        }
    }

    func test_xAxis_categories() throws {
        let source = "xychart\nx-axis [cat1, cat2, cat3]\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.xAxis.kind, .band)
        XCTAssertEqual(chart.xAxis.categories, ["cat1", "cat2", "cat3"])
        XCTAssertEqual(chart.xAxis.categoryTexts?.map(\.text), ["cat1", "cat2", "cat3"])
        XCTAssertTrue(chart.xAxis.hasSetAxis)
    }

    func test_xAxis_categories_quoted() throws {
        let source = "xychart\nx-axis [\"Cat 1\", \"Cat 2\", Cat3]\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.xAxis.kind, .band)
        XCTAssertEqual(chart.xAxis.categories, ["Cat 1", "Cat 2", "Cat3"])
    }

    func test_xAxis_categories_concatenateTextTokensUntilComma() throws {
        let source = "xychart\nx-axis [\"Cat 1\", cat2 asdf, cat3]\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.xAxis.categories, ["Cat 1", "cat2asdf", "cat3"])
    }

    func test_xAxis_markdownCategoryPreservesKind() throws {
        let source = "xychart\nx-axis [\"`Q1`\", Q2]\nline [1,2]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.xAxis.categoryTexts?.first?.text, "Q1")
        XCTAssertEqual(chart.xAxis.categoryTexts?.first?.kind, .markdown)
    }

    func test_xAxis_categories_unbalancedBrackets_throws() {
        let source = "xychart\nx-axis [a, [b]"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.unbalancedBrackets = error else {
                XCTFail("Expected unbalancedBrackets, got \(error)")
                return
            }
        }
    }

    // MARK: - Y-axis tests

    func test_yAxis_titleOnly() throws {
        let source = "xychart\ny-axis yAxisName\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.yAxis.title, "yAxisName")
        XCTAssertEqual(chart.yAxis.titleText?.text, "yAxisName")
        XCTAssertTrue(chart.yAxis.hasSetAxis)
    }

    func test_yAxis_range() throws {
        let source = "xychart\ny-axis 0 --> 100\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.yAxis.kind, .linear)
        XCTAssertEqual(chart.yAxis.range?.min, 0)
        XCTAssertEqual(chart.yAxis.range?.max, 100)
        XCTAssertTrue(chart.yAxis.hasSetAxis)
    }

    func test_yAxis_categoricalData_throws() {
        let source = "xychart\ny-axis [cat1, cat2]\nline [1,2,3]"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.categoricalYAxis = error else {
                XCTFail("Expected categoricalYAxis, got \(error)")
                return
            }
        }
    }

    // MARK: - Line data with titles

    func test_line_withTitle() throws {
        let source = "xychart\nline lineTitle [23, 45, 56.6]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.series.count, 1)
        let series = chart.series[0]
        XCTAssertEqual(series.type, .line)
        XCTAssertEqual(series.title.text, "lineTitle")
        XCTAssertEqual(series.data, [23, 45, 56.6])
    }

    func test_line_withQuotedTitle() throws {
        let source = "xychart\nline \"Title Space\" [1, 2, 3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.series.count, 1)
        XCTAssertEqual(chart.series[0].title.text, "Title Space")
        XCTAssertEqual(chart.series[0].data, [1, 2, 3])
    }

    func test_line_withoutTitle() throws {
        let source = "xychart\nline [1, 2, 3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.series.count, 1)
        XCTAssertEqual(chart.series[0].title.text, "")
        XCTAssertEqual(chart.series[0].data, [1, 2, 3])
    }

    func test_line_withSigns() throws {
        let source = "xychart\nline [+23, -45, 56.6]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.series.count, 1)
        XCTAssertEqual(chart.series[0].data, [23, -45, 56.6])
    }

    func test_line_withLeadingDot() throws {
        let source = "xychart\nline [.33, 0.5]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.series.count, 1)
        XCTAssertEqual(chart.series[0].data, [0.33, 0.5])
    }

    // MARK: - Bar data with titles

    func test_bar_withTitle() throws {
        let source = "xychart\nbar barTitle [10, 20, 30]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.series.count, 1)
        let series = chart.series[0]
        XCTAssertEqual(series.type, .bar)
        XCTAssertEqual(series.title.text, "barTitle")
        XCTAssertEqual(series.data, [10, 20, 30])
    }

    func test_bar_withoutTitle() throws {
        let source = "xychart\nbar [10, 20, 30]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.series.count, 1)
        XCTAssertEqual(chart.series[0].type, .bar)
        XCTAssertEqual(chart.series[0].title.text, "")
        XCTAssertEqual(chart.series[0].data, [10, 20, 30])
    }

    // MARK: - Line error cases

    func test_line_unbalancedBrackets_throws() {
        let source = "xychart\nline [1, 2, [3]]"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.unbalancedBrackets = error else {
                XCTFail("Expected unbalancedBrackets, got \(error)")
                return
            }
        }
    }

    func test_line_noData_throws() {
        let source = "xychart\nline"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.missingData = error else {
                XCTFail("Expected missingData, got \(error)")
                return
            }
        }
    }

    func test_line_emptyData_throws() {
        let source = "xychart\nline [ ]"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.emptyData = error else {
                XCTFail("Expected emptyData, got \(error)")
                return
            }
        }
    }

    func test_line_doubleComma_throws() {
        let source = "xychart\nline [1,, 3]"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.malformedComma = error else {
                XCTFail("Expected malformedComma, got \(error)")
                return
            }
        }
    }

    func test_line_nonNumeric_throws() {
        let source = "xychart\nline [1, abc, 3]"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.nonNumericData = error else {
                XCTFail("Expected nonNumericData, got \(error)")
                return
            }
        }
    }

    func test_line_missingComma_throws() {
        let source = "xychart\nline [1 2]"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.malformedComma = error else {
                XCTFail("Expected malformedComma, got \(error)")
                return
            }
        }
    }

    func test_line_trailingComma_throws() {
        let source = "xychart\nline [1, 2,]"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.malformedComma = error else {
                XCTFail("Expected malformedComma, got \(error)")
                return
            }
        }
    }

    func test_line_exponentNotation_throws() {
        let source = "xychart\nline [1e3]"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.nonNumericData = error else {
                XCTFail("Expected nonNumericData, got \(error)")
                return
            }
        }
    }

    // MARK: - Bar error cases

    func test_bar_noData_throws() {
        let source = "xychart\nbar"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.missingData = error else {
                XCTFail("Expected missingData, got \(error)")
                return
            }
        }
    }

    func test_bar_emptyData_throws() {
        let source = "xychart\nbar [ ]"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.emptyData = error else {
                XCTFail("Expected emptyData, got \(error)")
                return
            }
        }
    }

    // MARK: - Multiple series

    func test_multipleBarAndLine() throws {
        let source = "xychart\nbar [1,2]\nbar [3,4]\nline [5,6]\nline [7,8]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.series.count, 4)
        XCTAssertEqual(chart.series[0].type, .bar)
        XCTAssertEqual(chart.series[0].data, [1, 2])
        XCTAssertEqual(chart.series[1].type, .bar)
        XCTAssertEqual(chart.series[1].data, [3, 4])
        XCTAssertEqual(chart.series[2].type, .line)
        XCTAssertEqual(chart.series[2].data, [5, 6])
        XCTAssertEqual(chart.series[3].type, .line)
        XCTAssertEqual(chart.series[3].data, [7, 8])
    }

    func test_simplestDocsExample_derivesLinearAxes() throws {
        let source = "xychart\nline [+1.3, .6, 2.4, -.34]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.xAxis.kind, .linear)
        XCTAssertEqual(chart.xAxis.range?.min, 1)
        XCTAssertEqual(chart.xAxis.range?.max, 4)
        XCTAssertEqual(chart.yAxis.range?.min, -0.34)
        XCTAssertEqual(chart.yAxis.range?.max, 2.4)
    }

    // MARK: - Accessibility

    func test_accTitle() throws {
        let source = "xychart\naccTitle: Accessible Title\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.accTitle, "Accessible Title")
    }

    func test_accDescr_singleLine() throws {
        let source = "xychart\naccDescr: Description\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.accDescr, "Description")
    }

    func test_accDescr_multiline() throws {
        let source = "xychart\naccDescr { Line1\n  Line2 }\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertNotNil(chart.accDescr)
        XCTAssertTrue(chart.accDescr?.contains("Line1") ?? false)
        XCTAssertTrue(chart.accDescr?.contains("Line2") ?? false)
    }

    // MARK: - Sanitization tests

    func test_sanitize_strips_script_tags() throws {
        let source = "xychart\ntitle \"<script>alert('xss')</script>My Chart\"\nline [1,2,3]"
        let chart = try parseXYChart(lines(source))
        XCTAssertEqual(chart.title, "alert('xss')My Chart")
        XCTAssertFalse(chart.title?.contains("<script") ?? true)
        XCTAssertFalse(chart.title?.contains("</script>") ?? true)
    }

    func test_sanitize_categories() throws {
        let source = "xychart\nx-axis [\"<script>bad</script>Cat\", Safe]\nline [1,2]"
        let chart = try parseXYChart(lines(source))
        let cats = chart.xAxis.categories ?? []
        XCTAssertEqual(cats.count, 2)
        XCTAssertFalse(cats[0].contains("<script"))
        XCTAssertFalse(cats[0].contains("</script>"))
    }

    // MARK: - No plot error

    func test_noSeries_throws() {
        let source = "xychart"
        XCTAssertThrowsError(try parseXYChart(lines(source))) { error in
            guard case XYChartParserError.noPlotData = error else {
                XCTFail("Expected noPlotData, got \(error)")
                return
            }
        }
    }
}
