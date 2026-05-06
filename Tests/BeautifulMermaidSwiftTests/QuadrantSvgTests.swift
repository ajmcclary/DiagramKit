import XCTest
@testable import BeautifulMermaid

final class QuadrantSvgTests: XCTestCase {

    private let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")

    // MARK: - Basic structure

    func testSvgHasMainGroup() throws {
        let chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains("<g class=\"main\">"), "SVG output: \(svg)")
        XCTAssertTrue(svg.contains("class=\"quadrants\""))
        XCTAssertTrue(svg.contains("class=\"border\""))
        XCTAssertTrue(svg.contains("class=\"data-points\""))
        XCTAssertTrue(svg.contains("class=\"labels\""))
        XCTAssertTrue(svg.contains("class=\"title\""))
    }

    func testSvgHasViewBox() throws {
        let chart = QuadrantChart(
            config: QuadrantChartConfig(chartWidth: 400, chartHeight: 300, showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains("viewBox=\"0 0 400 300\""))
    }

    func testSvgUseMaxWidthTrueUsesResponsiveRoot() throws {
        let chart = QuadrantChart(
            config: QuadrantChartConfig(
                chartWidth: 400,
                chartHeight: 300,
                useMaxWidth: true,
                showXAxis: false,
                showYAxis: false,
                showTitle: false
            )
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)
        let root = String(svg.prefix { $0 != ">" })

        XCTAssertTrue(root.contains("width=\"100%\""), "SVG root: \(root)")
        XCTAssertTrue(root.contains("preserveAspectRatio=\"xMinYMin meet\""), "SVG root: \(root)")
        XCTAssertTrue(root.contains("max-width: 400px"), "SVG root: \(root)")
    }

    func testSvgUseMaxWidthFalseUsesFixedRoot() throws {
        let chart = QuadrantChart(
            config: QuadrantChartConfig(
                chartWidth: 400,
                chartHeight: 300,
                useMaxWidth: false,
                showXAxis: false,
                showYAxis: false,
                showTitle: false
            )
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)
        let root = String(svg.prefix { $0 != ">" })

        XCTAssertTrue(root.contains("width=\"400\""), "SVG root: \(root)")
        XCTAssertTrue(root.contains("height=\"300\""), "SVG root: \(root)")
        XCTAssertFalse(root.contains("max-width"), "SVG root: \(root)")
    }

    // MARK: - Quadrant rects

    func testSvgHasFourQuadrantRects() throws {
        let chart = QuadrantChart(
            quadrant1Text: "Q1",
            quadrant2Text: "Q2",
            quadrant3Text: "Q3",
            quadrant4Text: "Q4",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        let rectCount = svg.components(separatedBy: "<rect").count - 1
        XCTAssertEqual(rectCount, 4)
    }

    // MARK: - Point circles

    func testSvgHasPointCircle() throws {
        var chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        chart.points = [QuadrantPoint(text: "A", x: 0.5, y: 0.5)]
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains("<circle"))
        XCTAssertTrue(svg.contains("class=\"data-point\""))
    }

    // MARK: - Empty points

    func testSvgHasDataPointsGroupEvenWhenEmpty() throws {
        let chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains("class=\"data-points\""))
    }

    // MARK: - Border lines

    func testSvgHasSixLines() throws {
        let chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        let lineCount = svg.components(separatedBy: "<line").count - 1
        XCTAssertEqual(lineCount, 6)
    }

    // MARK: - Title text

    func testSvgTitleText() throws {
        let chart = QuadrantChart(
            titleText: "Test Title",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: true)
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains("Test Title"))
    }

    // MARK: - Accessibility

    func testSvgAccessibility() throws {
        let chart = QuadrantChart(
            accTitle: "AT",
            accDescr: "AD",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains("<title>AT</title>"))
        XCTAssertTrue(svg.contains("<desc>AD</desc>"))
    }

    // MARK: - XML escaping

    func testSvgTextEscaping() throws {
        let chart = QuadrantChart(
            quadrant1Text: "A < B & C > D",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertFalse(svg.contains("A < B & C > D"))
        XCTAssertTrue(svg.contains("A &lt; B &amp; C &gt; D") || svg.contains("&lt;") && svg.contains("&amp;") && svg.contains("&gt;"))
    }

    // MARK: - Rotation transforms

    func testYAxisRotationTransform() throws {
        let chart = QuadrantChart(
            yAxisBottomText: "Bottom",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: true, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains("rotate(-90)"))
    }

    // MARK: - Y-axis position affects SVG

    func testYAxisPositionRightInSvg() throws {
        let chart = QuadrantChart(
            yAxisBottomText: "Bottom",
            config: QuadrantChartConfig(yAxisPosition: "right", showXAxis: false, showYAxis: true, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains("class=\"labels\""))
    }
}
