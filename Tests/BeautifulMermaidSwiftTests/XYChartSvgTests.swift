import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

final class XYChartSvgTests: XCTestCase {

    func test_svg_viewBox_uses_config_dimensions() async throws {
        let source = """
        ---
        config:
          xyChart:
            width: 900
            height: 600
        ---
        xychart
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("viewBox=\"0 0 900 600\""), "Expected viewBox to use configured dimensions")
    }

    func test_svg_frontmatterTitle_rendersWhenInlineTitleAbsent() async throws {
        let source = """
        ---
        title: Frontmatter Sales
        ---
        xychart
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains(">Frontmatter Sales</text>"), "Expected frontmatter title to render as chart title")
    }

    func test_svg_backgroundRect_exists() async throws {
        let source = """
        xychart
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("class=\"xychart-background\""), "Expected background rect with class xychart-background")
    }

    func test_svg_axisLines_exist() async throws {
        let source = """
        xychart
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("class=\"xychart-axis-line\""), "Expected axis lines in SVG")
    }

    func test_svg_bars_are_rects_in_parity_mode() async throws {
        let source = """
        xychart
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
            line [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("class=\"xychart-bar-rect"), "Expected rect elements for bars in parity mode")
    }

    func test_svg_lines_are_straight_in_parity_mode() async throws {
        let source = """
        xychart
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
            line [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains(" L"), "Expected L path commands for straight lines in parity mode")
        XCTAssertFalse(svg.contains(" C"), "Expected no C curve path commands in parity mode")
    }

    func test_svg_dataLabels_exist_when_enabled() async throws {
        let source = """
        ---
        config:
          xyChart:
            showDataLabel: true
        ---
        xychart
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("class=\"xychart-data-label\""), "Expected data labels when showDataLabel is true")
    }

    func test_svg_horizontalDataLabels_exist_whenEnabled() async throws {
        let source = """
        ---
        config:
          xyChart:
            chartOrientation: horizontal
            showDataLabel: true
        ---
        xychart
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("class=\"xychart-data-label\""), "Expected data labels for horizontal bars")
    }

    func test_svg_axisFontConfig_isRendered() async throws {
        let source = """
        ---
        config:
          xyChart:
            xAxis:
              labelFontSize: 22
            yAxis:
              titleFontSize: 24
        ---
        xychart
            x-axis "Quarter" [A, B, C]
            y-axis "Revenue" 0 --> 50
            bar [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("font-size=\"22\""), "Expected x-axis label font size from config")
        XCTAssertTrue(svg.contains("font-size=\"24\""), "Expected y-axis title font size from config")
    }

    func test_svg_dataLabels_absent_when_disabled() async throws {
        let source = """
        xychart
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertFalse(svg.contains("class=\"xychart-data-label\""), "Expected no data labels by default")
    }

    func test_svg_accessibility_title() async throws {
        let source = """
        xychart
            accTitle "My XY Chart"
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<title>"), "Expected <title> element for accTitle")
    }

    func test_svg_accessibility_desc() async throws {
        let source = """
        xychart
            accDescr "A test description"
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<desc>"), "Expected <desc> element for accDescr")
    }

    // MARK: - Theme variable visual tests

    func test_svg_themePalette_colors_applied() async throws {
        let source = """
        ---
        config:
          themeVariables:
            xyChart:
              plotColorPalette: "#FF0000, #00FF00, #0000FF"
        ---
        xychart
            x-axis [A, B]
            y-axis 0 --> 50
            bar [10, 20]
            line [15, 25]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("#FF0000") || svg.contains("#ff0000"), "Expected first palette color in SVG output")
    }

    func test_svg_themePalette_fallback_when_empty() async throws {
        let source = """
        ---
        config:
          themeVariables:
            xyChart:
              plotColorPalette: ""
        ---
        xychart
            x-axis [A, B]
            y-axis 0 --> 50
            bar [10, 20]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("class=\"xychart-bar-rect"), "Expected bars rendered with fallback colors when palette is empty")
    }

    func test_svg_themeBackgroundColor_applied() async throws {
        let source = """
        ---
        config:
          themeVariables:
            xyChart:
              backgroundColor: "#f0f0f0"
        ---
        xychart
            x-axis [A]
            y-axis 0 --> 10
            bar [5]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("#f0f0f0"), "Expected background color from theme in SVG")
    }

    // MARK: - Data label visual tests

    func test_svg_horizontalOutsideDataLabels_positioned_correctly() async throws {
        let source = """
        ---
        config:
          xyChart:
            chartOrientation: horizontal
            showDataLabel: true
            showDataLabelOutsideBar: true
        ---
        xychart
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("text-anchor=\"start\""), "Expected start-anchored data labels when outside horizontal bars")
    }

    func test_svg_verticalOutsideDataLabels_aboveBars() async throws {
        let source = """
        ---
        config:
          xyChart:
            showDataLabel: true
            showDataLabelOutsideBar: true
        ---
        xychart
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("class=\"xychart-data-label\""), "Expected data labels when outside bars enabled")
    }

    // MARK: - Config flag tests

    func test_svg_title_hidden_when_showTitle_false() async throws {
        let source = """
        ---
        config:
          xyChart:
            showTitle: false
        ---
        xychart
            title "Should Be Hidden"
            x-axis [A]
            y-axis 0 --> 10
            bar [5]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertFalse(svg.contains(">Should Be Hidden</text>"), "Expected chart title to be hidden when showTitle is false")
    }

    func test_svg_ticks_hidden_when_showTick_false() async throws {
        let source = """
        ---
        config:
          xyChart:
            xAxis:
              showTick: false
            yAxis:
              showTick: false
        ---
        xychart
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertFalse(svg.contains("class=\"xychart-tick\""), "Expected no tick marks when showTick is false")
    }

    func test_svg_axisLines_hidden_when_showAxisLine_false() async throws {
        let source = """
        ---
        config:
          xyChart:
            xAxis:
              showAxisLine: false
            yAxis:
              showAxisLine: false
        ---
        xychart
            x-axis [A, B, C]
            y-axis 0 --> 50
            bar [10, 20, 30]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertFalse(svg.contains("class=\"xychart-axis-line\""), "Expected no axis lines when showAxisLine is false")
    }

    func test_svg_multiline_accDescr_in_output() async throws {
        let source = """
        xychart
            accDescr {
              This is a multiline
              access description
              for testing purposes.
            }
            x-axis [A]
            y-axis 0 --> 10
            bar [5]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<desc>"), "Expected <desc> element for multiline accDescr")
    }
}
