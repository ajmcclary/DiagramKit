import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

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

    // MARK: - SVG DOM structure

    func testSvgHasCorrectGroupHierarchy() throws {
        let chart = QuadrantChart(
            titleText: "Hello",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: true)
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        let quadrantsIdx = svg.range(of: #"class="quadrants""#)!.lowerBound
        let borderIdx = svg.range(of: #"class="border""#)!.lowerBound
        let dataPointsIdx = svg.range(of: #"class="data-points""#)!.lowerBound
        let labelsIdx = svg.range(of: #"class="labels""#)!.lowerBound
        let titleIdx = svg.range(of: #"class="title""#)!.lowerBound

        XCTAssertLessThan(quadrantsIdx, borderIdx, "quadrants group should appear before border group")
        XCTAssertLessThan(borderIdx, dataPointsIdx, "border group should appear before data-points group")
        XCTAssertLessThan(dataPointsIdx, labelsIdx, "data-points group should appear before labels group")
        XCTAssertLessThan(labelsIdx, titleIdx, "labels group should appear before title group")
    }

    func testSvgQuadrantRectsHaveCorrectFillColors() throws {
        let theme = QuadrantChartThemeConfig(
            quadrant1Fill: "#FF0000",
            quadrant2Fill: "#00FF00",
            quadrant3Fill: "#0000FF",
            quadrant4Fill: "#FFFF00"
        )
        let chart = QuadrantChart(
            quadrant1Text: "Q1",
            quadrant2Text: "Q2",
            quadrant3Text: "Q3",
            quadrant4Text: "Q4",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false),
            theme: theme
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains("fill=\"#FF0000\""), "quadrant-1 should have red fill")
        XCTAssertTrue(svg.contains("fill=\"#00FF00\""), "quadrant-2 should have green fill")
        XCTAssertTrue(svg.contains("fill=\"#0000FF\""), "quadrant-3 should have blue fill")
        XCTAssertTrue(svg.contains("fill=\"#FFFF00\""), "quadrant-4 should have yellow fill")
    }

    func testSvgPointCirclesHaveStyleAttributes() throws {
        var chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        chart.points = [QuadrantPoint(text: "A", x: 0.5, y: 0.5, radius: 10, color: "#FF0000", strokeColor: "#00FF00", strokeWidth: "3px")]
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains("fill=\"#FF0000\""))
        XCTAssertTrue(svg.contains("stroke=\"#00FF00\""))
        XCTAssertTrue(svg.contains("stroke-width=\"3px\""))
        XCTAssertTrue(svg.contains("r=\"10\"") || svg.contains("r=\"10.0\""))
    }

    func testSvgCircleOrderMatchesMermaidZOrder() throws {
        let source = """
        quadrantChart
        A: [0.1, 0.1]
        B: [0.2, 0.2]
        C: [0.3, 0.3]
        """
        let chart = try parseQuadrantChart(source.split(separator: "\n").map(String.init), frontmatter: nil)
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        // Parser prepends: stored order is [C, B, A] (Mermaid addPoints behavior)
        XCTAssertEqual(positioned.points.count, 3)
        XCTAssertEqual(positioned.points[0].text.text, "C")
        XCTAssertEqual(positioned.points[1].text.text, "B")
        XCTAssertEqual(positioned.points[2].text.text, "A")

        // SVG should contain each point text label
        XCTAssertTrue(svg.contains(">" + "A" + "<"))
        XCTAssertTrue(svg.contains(">" + "B" + "<"))
        XCTAssertTrue(svg.contains(">" + "C" + "<"))
    }

    func testSvgAriaAttributes() throws {
        let chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains(#"role="graphics-document""#))
        XCTAssertTrue(svg.contains(#"aria-roledescription="quadrant-chart""#))
        XCTAssertFalse(svg.contains(#"aria-roledescription="diagram""#))
    }

    func testSvgPointClassStyleRendering() throws {
        var chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        chart.classes["myClass"] = QuadrantPointStyles(radius: 15, color: "#FF00FF")
        chart.points = [QuadrantPoint(text: "Styled", x: 0.5, y: 0.5, className: "myClass")]
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains("fill=\"#FF00FF\""), "Point should use class-defined fill color")
        XCTAssertTrue(svg.contains("r=\"15\"") || svg.contains("r=\"15.0\""), "Point should use class-defined radius")
    }

    func testSvgFullDomElementCounts() throws {
        var chart = QuadrantChart(
            xAxisLeftText: "Left",
            xAxisRightText: "Right",
            yAxisBottomText: "Bottom",
            yAxisTopText: "Top",
            quadrant1Text: "Q1",
            quadrant2Text: "Q2",
            quadrant3Text: "Q3",
            quadrant4Text: "Q4",
            config: QuadrantChartConfig(showXAxis: true, showYAxis: true, showTitle: false)
        )
        chart.points = [
            QuadrantPoint(text: "A", x: 0.3, y: 0.6),
            QuadrantPoint(text: "B", x: 0.7, y: 0.4),
        ]
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        let rectCount = svg.components(separatedBy: "<rect").count - 1
        let lineCount = svg.components(separatedBy: "<line").count - 1
        let circleCount = svg.components(separatedBy: "<circle").count - 1
        let dataPointTextCount = svg.components(separatedBy: "class=\"data-point\"").count - 1
        let quadrantCount = svg.components(separatedBy: "class=\"quadrant\"").count - 1

        XCTAssertEqual(rectCount, 4, "Should have 4 quadrant rects")
        XCTAssertEqual(lineCount, 6, "Should have 6 border lines (4 outer + 2 inner)")
        XCTAssertEqual(circleCount, 2, "Should have 2 point circles")
        XCTAssertEqual(dataPointTextCount, 2, "Should have 2 data-point groups")
        XCTAssertEqual(quadrantCount, 4, "Should have 4 quadrant groups")
    }

    func testSvgTextElementsUseDominantBaseline() throws {
        let chart = QuadrantChart(
            titleText: "Hello",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: true)
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains("dominant-baseline="), "Text elements should have dominant-baseline attribute")
    }

    // MARK: - Image export verification

    func testSvgExportDimensionsMatchConfig() throws {
        let chart = QuadrantChart(
            config: QuadrantChartConfig(
                chartWidth: 400,
                chartHeight: 300,
                showXAxis: false,
                showYAxis: false,
                showTitle: false
            )
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains(#"viewBox="0 0 400 300""#), "SVG should have correct viewBox matching configured dimensions")
    }

    func testRenderMermaidSVGIntegrationReturnsNonEmptyString() throws {
        let source = """
        quadrantChart
            x-axis Low --> High
            y-axis Low --> High
            quadrant-1 Plan
        """
        let svg = try _renderMermaidSVG(source)
        XCTAssertFalse(svg.isEmpty)
        XCTAssertTrue(svg.contains("class=\"main\""))
        XCTAssertTrue(svg.contains("Plan"))
    }

    func testSvgExportUnicodeTextNotEscaped() throws {
        let chart = QuadrantChart(
            quadrant1Text: "拡張が必要",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertTrue(svg.contains("拡張が必要"), "CJK text should be present in SVG output")
    }
}
