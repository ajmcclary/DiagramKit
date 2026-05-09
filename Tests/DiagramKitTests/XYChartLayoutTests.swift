import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

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

    // MARK: - Linear X-axis behavior (Mermaid parity: always band for positioning)

    func test_layout_linearXAxis_generatesInterpolatedLabels() throws {
        let source = "xychart\nx-axis 0 --> 100\nline [10, 30, 50, 70, 90]"
        let lines = source.split(separator: "\n").map(String.init)
        let chart = try parseXYChart(lines)
        XCTAssertEqual(chart.xAxis.kind, .linear)
        let positioned = layoutXYChart(chart)
        let labels = positioned.xAxis.ticks.map(\.label)
        XCTAssertEqual(labels, ["0", "25", "50", "75", "100"])
    }

    func test_layout_linearXAxis_dataPointsEvenlySpaced() throws {
        let source = "xychart\nx-axis 0 --> 100\nline [10, 30, 50, 70, 90]"
        let lines = source.split(separator: "\n").map(String.init)
        let chart = try parseXYChart(lines)
        let positioned = layoutXYChart(chart)
        let line = try XCTUnwrap(positioned.lines.first)
        XCTAssertEqual(line.points.count, 5, "Expected 5 line points")
        let xGaps = zip(line.points, line.points.dropFirst()).map { $1.x - $0.x }
        XCTAssertTrue(xGaps.allSatisfy { abs($0 - xGaps[0]) < 1 }, "Expected evenly spaced x-positions for linear x-axis line")
    }

    func test_layout_linearXAxis_barsEvenlySpaced() throws {
        let source = "xychart\nx-axis 10 --> 50\nbar [100, 200, 300]"
        let lines = source.split(separator: "\n").map(String.init)
        let chart = try parseXYChart(lines)
        let positioned = layoutXYChart(chart)
        XCTAssertEqual(positioned.bars.count, 3, "Expected 3 bars")
        let xGaps = zip(positioned.bars, positioned.bars.dropFirst()).map { $1.x - $0.x }
        XCTAssertTrue(xGaps.allSatisfy { abs($0 - xGaps[0]) < 1 }, "Expected evenly spaced x-positions for linear x-axis bars")
    }

    func test_layout_bandXAxis_usesCategoricalLabels() throws {
        let source = "xychart\nx-axis [A, B, C]\nbar [10, 20, 30]"
        let lines = source.split(separator: "\n").map(String.init)
        let chart = try parseXYChart(lines)
        XCTAssertEqual(chart.xAxis.kind, .band)
        let positioned = layoutXYChart(chart)
        let labels = positioned.xAxis.ticks.map(\.label)
        XCTAssertEqual(labels, ["A", "B", "C"])
    }

    func test_layout_noXAxis_usesLinear1toN() throws {
        let source = "xychart\nline [10, 20, 30, 40]"
        let lines = source.split(separator: "\n").map(String.init)
        let chart = try parseXYChart(lines)
        XCTAssertEqual(chart.xAxis.kind, .linear)
        XCTAssertEqual(chart.xAxis.range?.min, 1)
        XCTAssertEqual(chart.xAxis.range?.max, 4)
    }

    func test_layout_noYAxis_usesExactMinMax() throws {
        let source = "xychart\nx-axis [A, B]\nbar [10.5, 30.2]"
        let lines = source.split(separator: "\n").map(String.init)
        let chart = try parseXYChart(lines)
        XCTAssertEqual(chart.yAxis.range?.min, 10.5)
        XCTAssertEqual(chart.yAxis.range?.max, 30.2)
    }

    // MARK: - textKind threading

    func test_layout_titleTextKind_preserved() throws {
        let source = "xychart\ntitle \"`**Sales**`\"\nline [1,2,3]"
        let lines = source.split(separator: "\n").map(String.init)
        let chart = try parseXYChart(lines)
        XCTAssertEqual(chart.titleText?.kind, .markdown)
        let positioned = layoutXYChart(chart)
        XCTAssertEqual(positioned.title?.textKind, .markdown)
    }

    func test_layout_axisTitleTextKind_preserved() throws {
        let source = "xychart\nx-axis \"`**Quarter**`\" [A, B, C]\nbar [10, 20, 30]"
        let lines = source.split(separator: "\n").map(String.init)
        let chart = try parseXYChart(lines)
        XCTAssertEqual(chart.xAxis.titleText?.kind, .markdown)
        let positioned = layoutXYChart(chart)
        XCTAssertEqual(positioned.xAxis.title?.textKind, .markdown)
    }
}
