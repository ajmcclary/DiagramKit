import XCTest
@testable import BeautifulMermaid

final class XYChartLayoutTests: XCTestCase {

    func test_layout_dimensions_match_config() throws {
        let source = "xychart\nx-axis [A, B, C]\ny-axis 0 --> 50\nbar [10, 20, 30]"
        let lines = source.split(separator: "\n").map(String.init)
        var chart = try parseXYChart(lines)
        XCTAssertNotNil(chart.yAxis.range, "yAxis.range should be set")
        XCTAssertFalse(chart.series.isEmpty, "series should be non-empty")
        chart.config = XYChartConfig(width: 900, height: 600)
        let positioned = layoutXYChart(chart)
        XCTAssertEqual(positioned.width, 900)
        XCTAssertEqual(positioned.height, 600)
    }

    func test_layout_simplestDocsExample_hasNonZeroPlotArea() throws {
        let source = "xychart\nline [+1.3, .6, 2.4, -.34]"
        let lines = source.split(separator: "\n").map(String.init)
        let chart = try parseXYChart(lines)
        let positioned = layoutXYChart(chart)
        XCTAssertGreaterThan(positioned.plotArea.width, 0)
        XCTAssertGreaterThan(positioned.plotArea.height, 0)
        XCTAssertFalse(positioned.lines.first?.points.isEmpty ?? true)
    }

    func test_layout_plotReservedSpacePercent_setsMinimumPlotSpace() throws {
        let source = "xychart\nx-axis [A, B, C]\ny-axis 0 --> 50\nbar [10, 20, 30]"
        let lines = source.split(separator: "\n").map(String.init)
        var chart = try parseXYChart(lines)
        chart.config = XYChartConfig(width: 700, height: 500, plotReservedSpacePercent: 90)
        let positioned = layoutXYChart(chart)
        XCTAssertGreaterThanOrEqual(positioned.plotArea.width, 630)
        XCTAssertGreaterThanOrEqual(positioned.plotArea.height, 450)
    }

    func test_layout_horizontal_orientation() throws {
        let source = "xychart\nx-axis [A, B, C]\ny-axis 0 --> 50\nbar [10, 20, 30]"
        let lines = source.split(separator: "\n").map(String.init)
        var chart = try parseXYChart(lines)
        chart.config = XYChartConfig(chartOrientation: "horizontal")
        let positioned = layoutXYChart(chart)
        XCTAssertTrue(positioned.horizontal, "Expected horizontal orientation in positioned chart")
    }

    func test_layout_hasTickLines() throws {
        let source = "xychart\nx-axis [A, B, C]\ny-axis 0 --> 50\nbar [10, 20, 30]"
        let lines = source.split(separator: "\n").map(String.init)
        let chart = try parseXYChart(lines)
        let positioned = layoutXYChart(chart)
        XCTAssertFalse(positioned.xAxis.tickLines.isEmpty, "Expected tick lines when showTick defaults to true")
    }

    func test_layout_dataLabels_when_enabled() throws {
        let source = "xychart\nx-axis [A, B, C]\ny-axis 0 --> 50\nbar [10, 20, 30]"
        let lines = source.split(separator: "\n").map(String.init)
        var chart = try parseXYChart(lines)
        chart.config = XYChartConfig(showDataLabel: true)
        let positioned = layoutXYChart(chart)
        XCTAssertFalse(positioned.bars.isEmpty, "Expected bars in positioned chart")
        let dataLabels = positioned.bars.compactMap(\.dataLabel)
        XCTAssertFalse(dataLabels.isEmpty, "Expected data labels on bars when showDataLabel is true")
        XCTAssertEqual(dataLabels.count, positioned.bars.count, "Expected data label for every bar")
    }

    func test_layout_verticalOutsideDataLabels_areAboveBars() throws {
        let source = "xychart\nx-axis [A, B, C]\ny-axis 0 --> 50\nbar [10, 20, 30]"
        let lines = source.split(separator: "\n").map(String.init)
        var chart = try parseXYChart(lines)
        chart.config = XYChartConfig(showDataLabel: true, showDataLabelOutsideBar: true)
        let positioned = layoutXYChart(chart)
        let firstBar = try XCTUnwrap(positioned.bars.first)
        let firstLabel = try XCTUnwrap(firstBar.dataLabel)
        XCTAssertLessThan(firstLabel.y, firstBar.y)
    }
}
