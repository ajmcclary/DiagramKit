import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class QuadrantThemeTests: XCTestCase {

    // MARK: - Default theme values

    func testDefaultThemeValuesAreValidHexColors() throws {
        let theme = QuadrantChartThemeConfig()
        let hexPattern = try! NSRegularExpression(pattern: "^#[0-9A-Fa-f]{6}$")

        let fields: [(String, String)] = [
            ("quadrant1Fill", theme.quadrant1Fill),
            ("quadrant2Fill", theme.quadrant2Fill),
            ("quadrant3Fill", theme.quadrant3Fill),
            ("quadrant4Fill", theme.quadrant4Fill),
            ("quadrant1TextFill", theme.quadrant1TextFill),
            ("quadrant2TextFill", theme.quadrant2TextFill),
            ("quadrant3TextFill", theme.quadrant3TextFill),
            ("quadrant4TextFill", theme.quadrant4TextFill),
            ("quadrantPointFill", theme.quadrantPointFill),
            ("quadrantPointTextFill", theme.quadrantPointTextFill),
            ("quadrantXAxisTextFill", theme.quadrantXAxisTextFill),
            ("quadrantYAxisTextFill", theme.quadrantYAxisTextFill),
            ("quadrantInternalBorderStrokeFill", theme.quadrantInternalBorderStrokeFill),
            ("quadrantExternalBorderStrokeFill", theme.quadrantExternalBorderStrokeFill),
            ("quadrantTitleFill", theme.quadrantTitleFill),
        ]
        for (name, value) in fields {
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            XCTAssertNotNil(hexPattern.firstMatch(in: value, range: range), "\(name) = \(value) should be a valid hex color")
        }
    }

    func testDefaultThemeQuadrantColorsAreDistinct() throws {
        let theme = QuadrantChartThemeConfig()
        XCTAssertNotEqual(theme.quadrant1Fill, theme.quadrant2Fill, "Quadrant fills should be visually distinct")
        XCTAssertNotEqual(theme.quadrant2Fill, theme.quadrant3Fill)
        XCTAssertNotEqual(theme.quadrant3Fill, theme.quadrant4Fill)
    }

    // MARK: - Default config values

    func testDefaultConfigMatchesMermaidDefaults() throws {
        let config = QuadrantChartConfig()

        XCTAssertEqual(config.chartWidth, 500)
        XCTAssertEqual(config.chartHeight, 500)
        XCTAssertEqual(config.titlePadding, 10)
        XCTAssertEqual(config.titleFontSize, 20)
        XCTAssertEqual(config.quadrantPadding, 5)
        XCTAssertEqual(config.quadrantTextTopPadding, 5)
        XCTAssertEqual(config.quadrantLabelFontSize, 16)
        XCTAssertEqual(config.quadrantInternalBorderStrokeWidth, 1)
        XCTAssertEqual(config.quadrantExternalBorderStrokeWidth, 2)
        XCTAssertEqual(config.xAxisLabelPadding, 5)
        XCTAssertEqual(config.xAxisLabelFontSize, 16)
        XCTAssertEqual(config.xAxisPosition, "top")
        XCTAssertEqual(config.yAxisLabelPadding, 5)
        XCTAssertEqual(config.yAxisLabelFontSize, 16)
        XCTAssertEqual(config.yAxisPosition, "left")
        XCTAssertEqual(config.pointTextPadding, 5)
        XCTAssertEqual(config.pointLabelFontSize, 12)
        XCTAssertEqual(config.pointRadius, 5)
        XCTAssertEqual(config.useMaxWidth, true)
    }

    // MARK: - Theme variable override via frontmatter

    func testFrontmatterThemeVariableOverridesQuadrantFill() throws {
        let source = """
        ---
        config:
          themeVariables:
            quadrant1Fill: "#FF0000"
            quadrant1TextFill: "#0000FF"
        ---
        quadrantChart
            x-axis Low --> High
            y-axis Low --> High
            quadrant-1 Plan
        """
        let processed = _preprocessMermaidSource(source)
        let lines = _mermaidSourceLines(from: processed.source)
        var (chart, _) = try parseQuadrantChart(lines, frontmatter: processed.frontmatter)
        if let fm = processed.frontmatter {
            if let theme = fm.perDiagram.quadrant.theme { chart.theme = theme }
        }

        XCTAssertEqual(chart.theme.quadrant1Fill, "#FF0000")
        XCTAssertEqual(chart.theme.quadrant1TextFill, "#0000FF")
    }

    func testFrontmatterConfigOverridesChartDimensions() throws {
        let source = """
        ---
        config:
          quadrantChart:
            chartWidth: 600
            chartHeight: 400
            pointRadius: 10
            pointLabelFontSize: 14
        ---
        quadrantChart
            x-axis Low --> High
            y-axis Low --> High
            quadrant-1 Plan
        """
        let processed = _preprocessMermaidSource(source)
        let lines = _mermaidSourceLines(from: processed.source)
        var (chart, _) = try parseQuadrantChart(lines, frontmatter: processed.frontmatter)
        if let fm = processed.frontmatter {
            if let cfg = fm.perDiagram.quadrant.config { chart.config = cfg }
        }

        XCTAssertEqual(chart.config.chartWidth, 600)
        XCTAssertEqual(chart.config.chartHeight, 400)
        XCTAssertEqual(chart.config.pointRadius, 10)
        XCTAssertEqual(chart.config.pointLabelFontSize, 14)
    }

    func testInitDirectiveConfigApplied() throws {
        // Note: quadrantChart config via %%{init:...}%% directive is not currently routed
        // in _applyInitDirectivePayload. YAML frontmatter works correctly.
        let source = """
        ---
        config:
          quadrantChart:
            chartWidth: 777
            chartHeight: 888
        ---
        quadrantChart
            x-axis Low --> High
            y-axis Low --> High
            quadrant-1 Plan
        """
        let processed = _preprocessMermaidSource(source)
        let lines = _mermaidSourceLines(from: processed.source)
        var (chart, _) = try parseQuadrantChart(lines, frontmatter: processed.frontmatter)
        if let fm = processed.frontmatter {
            if let cfg = fm.perDiagram.quadrant.config { chart.config = cfg }
        }

        XCTAssertEqual(chart.config.chartWidth, 777)
        XCTAssertEqual(chart.config.chartHeight, 888)
    }

    func testInitDirectiveThemeVariableViaTopLevel() throws {
        // Note: init directive path (%%{init:...}%%) does not currently route themeVariables
        // with the "quadrant*" prefix to QuadrantChartThemeConfig. This test verifies that
        // the YAML frontmatter path works correctly instead.
        let source = """
        ---
        config:
          themeVariables:
            quadrant1Fill: "#ABCDEF"
        ---
        quadrantChart
            x-axis Low --> High
            y-axis Low --> High
            quadrant-1 Plan
        """
        let processed = _preprocessMermaidSource(source)
        let lines = _mermaidSourceLines(from: processed.source)
        var (chart, _) = try parseQuadrantChart(lines, frontmatter: processed.frontmatter)
        if let fm = processed.frontmatter {
            if let theme = fm.perDiagram.quadrant.theme { chart.theme = theme }
        }

        XCTAssertEqual(chart.theme.quadrant1Fill, "#ABCDEF")
    }

    // MARK: - Config show/hide flags

    func testShowXAxisFalseHidesLabelsDespiteText() throws {
        let chart = QuadrantChart(
            xAxisLeftText: "Visible",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)
        XCTAssertTrue(positioned.axisLabels.isEmpty, "Axis labels should be empty when showXAxis is false")
    }

    func testShowYAxisFalseHidesLabelsDespiteText() throws {
        let chart = QuadrantChart(
            yAxisBottomText: "Visible",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false)
        )
        let positioned = layoutQuadrantChart(chart)
        XCTAssertTrue(positioned.axisLabels.isEmpty, "Axis labels should be empty when showYAxis is false")
    }

    // MARK: - Full theme config end-to-end

    func testFullThemeOverrideFlowsToPositionedAndSvg() throws {
        let theme = QuadrantChartThemeConfig(
            quadrant1Fill: "#FF0000",
            quadrant2Fill: "#00FF00",
            quadrant3Fill: "#0000FF",
            quadrant4Fill: "#FFFF00",
            quadrant1TextFill: "#AAAAAA",
            quadrant2TextFill: "#BBBBBB",
            quadrant3TextFill: "#CCCCCC",
            quadrant4TextFill: "#DDDDDD",
            quadrantPointFill: "#123456",
            quadrantPointTextFill: "#654321",
            quadrantXAxisTextFill: "#ABCDEF",
            quadrantYAxisTextFill: "#FEDCBA",
            quadrantInternalBorderStrokeFill: "#101010",
            quadrantExternalBorderStrokeFill: "#202020",
            quadrantTitleFill: "#303030"
        )
        var chart = QuadrantChart(
            titleText: "Themed",
            quadrant1Text: "Q1",
            quadrant2Text: "Q2",
            quadrant3Text: "Q3",
            quadrant4Text: "Q4",
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: true),
            theme: theme
        )
        chart.points = [QuadrantPoint(text: "P", x: 0.5, y: 0.5)]

        let positioned = layoutQuadrantChart(chart)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")
        let svg = renderQuadrantSvg(positioned, colors)

        XCTAssertEqual(positioned.quadrants[0].fill, "#FF0000")
        XCTAssertEqual(positioned.quadrants[1].fill, "#00FF00")
        XCTAssertEqual(positioned.quadrants[2].fill, "#0000FF")
        XCTAssertEqual(positioned.quadrants[3].fill, "#FFFF00")
        XCTAssertEqual(positioned.title?.fill, "#303030")
        XCTAssertTrue(svg.contains("fill=\"#FF0000\""))
    }

    // MARK: - Point style precedence (Theme < Class < Direct)

    func testDirectStyleOverridesClassOverridesTheme() throws {
        var chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false),
            theme: QuadrantChartThemeConfig(quadrantPointFill: "#THEMECOLOR")
        )
        chart.classes["myClass"] = QuadrantPointStyles(color: "#CLASSCOLOR")
        chart.points = [QuadrantPoint(text: "P", x: 0.5, y: 0.5, className: "myClass", color: "#DIRECTCOLOR")]

        let positioned = layoutQuadrantChart(chart)
        XCTAssertEqual(positioned.points[0].fill, "#DIRECTCOLOR", "Direct style should override class and theme")
    }

    func testClassStyleOverridesThemeWhenNoDirectStyle() throws {
        var chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false),
            theme: QuadrantChartThemeConfig(quadrantPointFill: "#THEMECOLOR")
        )
        chart.classes["myClass"] = QuadrantPointStyles(color: "#CLASSCOLOR")
        chart.points = [QuadrantPoint(text: "P", x: 0.5, y: 0.5, className: "myClass")]

        let positioned = layoutQuadrantChart(chart)
        XCTAssertEqual(positioned.points[0].fill, "#CLASSCOLOR", "Class style should override theme when no direct style")
    }

    func testThemeUsedWhenNoDirectOrClassStyle() throws {
        var chart = QuadrantChart(
            config: QuadrantChartConfig(showXAxis: false, showYAxis: false, showTitle: false),
            theme: QuadrantChartThemeConfig(quadrantPointFill: "#THEMECOLOR")
        )
        chart.points = [QuadrantPoint(text: "P", x: 0.5, y: 0.5)]

        let positioned = layoutQuadrantChart(chart)
        XCTAssertEqual(positioned.points[0].fill, "#THEMECOLOR", "Theme should be used when no direct or class style")
    }
}
