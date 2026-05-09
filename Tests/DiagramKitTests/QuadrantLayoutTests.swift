import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class QuadrantLayoutTests: XCTestCase {

    // MARK: - Empty chart tests

    func testEmptyChartLayout() throws {
        let chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)

        XCTAssertEqual(positioned.width, 500)
        XCTAssertEqual(positioned.height, 500)
        XCTAssertEqual(positioned.quadrants.count, 4)
        XCTAssertTrue(positioned.points.isEmpty)
        XCTAssertTrue(positioned.axisLabels.isEmpty)
        XCTAssertNil(positioned.title)
        XCTAssertEqual(positioned.borderLines.count, 6)
    }

    func testQuadrantSpatialMapping() {
        let chart = QuadrantChart(
            quadrant1Text: "TR",
            quadrant2Text: "TL",
            quadrant3Text: "BL",
            quadrant4Text: "BR",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)

        XCTAssertEqual(positioned.quadrants.count, 4)
        // 1=TR, 2=TL, 3=BL, 4=BR
        XCTAssertEqual(positioned.quadrants[0].text.text, "TR")
        XCTAssertEqual(positioned.quadrants[1].text.text, "TL")
        XCTAssertEqual(positioned.quadrants[2].text.text, "BL")
        XCTAssertEqual(positioned.quadrants[3].text.text, "BR")

        // TR x > TL x, TR y == TL y
        XCTAssertGreaterThan(positioned.quadrants[0].x, positioned.quadrants[1].x)
        XCTAssertEqual(positioned.quadrants[0].y, positioned.quadrants[1].y)
        // BL x == TL x, BL y > TR y
        XCTAssertEqual(positioned.quadrants[2].x, positioned.quadrants[1].x)
        XCTAssertGreaterThan(positioned.quadrants[2].y, positioned.quadrants[0].y)
    }

    // MARK: - No-points vs with-points behavior

    func testNoPointsQuadrantTextCentered() {
        let chart = QuadrantChart(
            quadrant1Text: "Q1",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)

        let q = positioned.quadrants.first(where: { $0.text.text == "Q1" })!
        XCTAssertEqual(q.text.horizontalPos, "middle")
    }

    func testWithPointsQuadrantTextTop() {
        var chart = QuadrantChart(
            quadrant1Text: "Q1",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        chart.points = [QuadrantPoint(text: "P", x: 0.5, y: 0.5)]
        let positioned = layoutQuadrantChart(chart)

        let q = positioned.quadrants.first(where: { $0.text.text == "Q1" })!
        XCTAssertEqual(q.text.horizontalPos, "top")
    }

    // MARK: - X-axis position tests

    func testXAxisLabelWhenNoPoints() {
        let chart = QuadrantChart(
            xAxisLeftText: "Left",
            config: QuadrantChartConfig(xAxisPosition: "top", showXAxis: true, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)

        XCTAssertEqual(positioned.axisLabels.count, 1)
        // When no points, x-axis stays at configured "top" position
        let label = positioned.axisLabels[0]
        XCTAssertLessThan(label.y, 250) // top half of chart
    }

    func testXAxisLabelsMoveToBottomWhenPointsExist() {
        var chart = QuadrantChart(
            xAxisLeftText: "Left",
            config: QuadrantChartConfig(xAxisPosition: "top", showXAxis: true, showYAxis: false, showTitle: false)
        )
        chart.points = [QuadrantPoint(text: "P", x: 0.5, y: 0.5)]
        let positioned = layoutQuadrantChart(chart)

        XCTAssertEqual(positioned.axisLabels.count, 1)
        // When points exist, x-axis moves to bottom regardless of config
        let label = positioned.axisLabels[0]
        XCTAssertGreaterThan(label.y, 250) // bottom half of chart
    }

    // MARK: - Y-axis position tests

    func testYAxisPositionLeft() {
        let chart = QuadrantChart(
            yAxisBottomText: "Bottom",
            config: QuadrantChartConfig(yAxisPosition: "left", showXAxis: false, showYAxis: true, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)

        let label = positioned.axisLabels[0]
        XCTAssertLessThan(label.x, 250) // left of center
    }

    func testYAxisPositionRight() {
        let chart = QuadrantChart(
            yAxisBottomText: "Bottom",
            config: QuadrantChartConfig(yAxisPosition: "right", showXAxis: false, showYAxis: true, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)

        let label = positioned.axisLabels[0]
        XCTAssertGreaterThan(label.x, 250) // right of center
    }

    // MARK: - Point coordinate mapping

    func testPointMappingBottomLeft() {
        var chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        chart.points = [QuadrantPoint(text: "P", x: 0, y: 0)]
        let positioned = layoutQuadrantChart(chart)

        XCTAssertEqual(positioned.points.count, 1)
        let p = positioned.points[0]
        // y=0 should be at the bottom of the quadrant area
        let quadrantArea = positioned.quadrants[2] // bottom-left quadrant
        XCTAssertGreaterThan(p.y, quadrantArea.y) // bottom area
        XCTAssertLessThan(p.x, positioned.width / 2) // left area
    }

    func testPointMappingTopRight() {
        var chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        chart.points = [QuadrantPoint(text: "P", x: 1, y: 1)]
        let positioned = layoutQuadrantChart(chart)

        let p = positioned.points[0]
        // y=1 should be at the top, x=1 at the right
        let quadrantArea = positioned.quadrants[0] // top-right quadrant
        XCTAssertLessThan(p.y, quadrantArea.y + quadrantArea.height / 2) // top area
        XCTAssertGreaterThan(p.x, positioned.width / 2) // right area
    }

    // MARK: - Point label positioning

    func testPointLabelBelowPoint() {
        var chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        chart.points = [QuadrantPoint(text: "Label", x: 0.5, y: 0.5)]
        let positioned = layoutQuadrantChart(chart)

        let p = positioned.points[0]
        // text y should be greater than point y (rendered below point)
        XCTAssertGreaterThan(p.text.y, p.y)
        // but close (just padding offset)
        XCTAssertLessThan(p.text.y - p.y, 20)
    }

    // MARK: - Axis label placement

    func testSingleXAxisLabelLeftAligned() {
        let chart = QuadrantChart(
            xAxisLeftText: "Only",
            config: QuadrantChartConfig(showXAxis: true, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)
        let label = positioned.axisLabels[0]
        XCTAssertEqual(label.verticalPos, "left")
    }

    func testBothXAxisLabelsCentered() {
        let chart = QuadrantChart(
            xAxisLeftText: "Left",
            xAxisRightText: "Right",
            config: QuadrantChartConfig(showXAxis: true, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)

        for axisLabel in positioned.axisLabels {
            XCTAssertEqual(axisLabel.verticalPos, "center")
        }
    }

    // MARK: - Y-axis rotation

    func testYAxisLabelsRotated() {
        let chart = QuadrantChart(
            yAxisBottomText: "Bottom",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: true, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)

        for axisLabel in positioned.axisLabels {
            XCTAssertEqual(axisLabel.rotation, -90)
        }
    }

    // MARK: - Title

    func testTitlePresent() {
        let chart = QuadrantChart(
            titleText: "Hello",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: true)
        )
        let positioned = layoutQuadrantChart(chart)

        XCTAssertNotNil(positioned.title)
        XCTAssertEqual(positioned.title?.text, "Hello")
        XCTAssertEqual(positioned.title?.x, 250) // centered
    }

    func testTitleAbsentWhenNoText() {
        let chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: true)
        )
        let positioned = layoutQuadrantChart(chart)

        XCTAssertNil(positioned.title)
    }

    func testTitleAbsentWhenShowTitleFalse() {
        let chart = QuadrantChart(
            titleText: "Hello",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)

        XCTAssertNil(positioned.title)
    }

    // MARK: - Border lines

    func testBordersAlwaysPresent() {
        let chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)

        XCTAssertEqual(positioned.borderLines.count, 6)
    }

    // MARK: - Accessibility pass-through

    func testAccessibilityPassThrough() {
        let chart = QuadrantChart(
            accTitle: "AT",
            accDescr: "AD",
            diagramTitle: "DT",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)

        XCTAssertEqual(positioned.accTitle, "AT")
        XCTAssertEqual(positioned.accDescr, "AD")
        XCTAssertEqual(positioned.diagramTitle, "DT")
    }
}
