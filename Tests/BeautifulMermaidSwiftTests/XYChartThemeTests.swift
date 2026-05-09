import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class XYChartThemeTests: XCTestCase {

    func test_theme_titleColor() {
        let yaml = """
        ---
        config:
          themeVariables:
            xyChart:
              titleColor: "#ff0000"
        ---
        xychart
        line [1, 2, 3]
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let theme = fm?.xyChartTheme
        XCTAssertEqual(theme?.titleColor, "#ff0000")
    }

    func test_theme_backgroundColor() {
        let yaml = """
        ---
        config:
          themeVariables:
            xyChart:
              backgroundColor: "#1a1a1a"
        ---
        xychart
        line [1, 2, 3]
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let theme = fm?.xyChartTheme
        XCTAssertEqual(theme?.backgroundColor, "#1a1a1a")
    }

    func test_theme_plotColorPalette() {
        let yaml = """
        ---
        config:
          themeVariables:
            xyChart:
              plotColorPalette: "#000000, #0000FF, #00FF00, #FF0000"
        ---
        xychart
        line [1, 2, 3]
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let theme = fm?.xyChartTheme
        XCTAssertEqual(theme?.plotColorPalette, "#000000, #0000FF, #00FF00, #FF0000")
    }

    func test_theme_axisColors() {
        let yaml = """
        ---
        config:
          themeVariables:
            xyChart:
              xAxisLabelColor: "#aaaaaa"
              xAxisTitleColor: "#bbbbbb"
              xAxisTickColor: "#cccccc"
              xAxisLineColor: "#dddddd"
              yAxisLabelColor: "#eeeeee"
              yAxisTitleColor: "#ffffff"
        ---
        xychart
        line [1, 2, 3]
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let theme = fm?.xyChartTheme
        XCTAssertEqual(theme?.xAxisLabelColor, "#aaaaaa")
        XCTAssertEqual(theme?.xAxisTitleColor, "#bbbbbb")
        XCTAssertEqual(theme?.xAxisTickColor, "#cccccc")
        XCTAssertEqual(theme?.xAxisLineColor, "#dddddd")
        XCTAssertEqual(theme?.yAxisLabelColor, "#eeeeee")
        XCTAssertEqual(theme?.yAxisTitleColor, "#ffffff")
    }

    func test_theme_allVariables() {
        let yaml = """
        ---
        config:
          themeVariables:
            xyChart:
              backgroundColor: "#111111"
              titleColor: "#222222"
              dataLabelColor: "#333333"
              xAxisLabelColor: "#444444"
              xAxisTitleColor: "#555555"
              xAxisTickColor: "#666666"
              xAxisLineColor: "#777777"
              yAxisLabelColor: "#888888"
              yAxisTitleColor: "#999999"
              yAxisTickColor: "#aaaaaa"
              yAxisLineColor: "#bbbbbb"
              plotColorPalette: "#000000, #0000FF, #00FF00, #FF0000"
        ---
        xychart
        line [1, 2, 3]
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let theme = fm?.xyChartTheme
        XCTAssertEqual(theme?.backgroundColor, "#111111")
        XCTAssertEqual(theme?.titleColor, "#222222")
        XCTAssertEqual(theme?.dataLabelColor, "#333333")
        XCTAssertEqual(theme?.xAxisLabelColor, "#444444")
        XCTAssertEqual(theme?.xAxisTitleColor, "#555555")
        XCTAssertEqual(theme?.xAxisTickColor, "#666666")
        XCTAssertEqual(theme?.xAxisLineColor, "#777777")
        XCTAssertEqual(theme?.yAxisLabelColor, "#888888")
        XCTAssertEqual(theme?.yAxisTitleColor, "#999999")
        XCTAssertEqual(theme?.yAxisTickColor, "#aaaaaa")
        XCTAssertEqual(theme?.yAxisLineColor, "#bbbbbb")
        XCTAssertEqual(theme?.plotColorPalette, "#000000, #0000FF, #00FF00, #FF0000")
    }

    func test_theme_dataLabelColor() {
        let yaml = """
        ---
        config:
          themeVariables:
            xyChart:
              dataLabelColor: "#ffffff"
        ---
        xychart
        line [1, 2, 3]
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let theme = fm?.xyChartTheme
        XCTAssertEqual(theme?.dataLabelColor, "#ffffff")
    }
}
