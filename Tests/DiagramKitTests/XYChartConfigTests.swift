import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class XYChartConfigTests: XCTestCase {

    func test_defaultConfig() {
        let config = XYChartConfig()
        XCTAssertEqual(config.width, 700)
        XCTAssertEqual(config.height, 500)
        XCTAssertEqual(config.titleFontSize, 20)
        XCTAssertEqual(config.titlePadding, 10)
        XCTAssertEqual(config.showTitle, true)
        XCTAssertEqual(config.showDataLabel, false)
        XCTAssertEqual(config.showDataLabelOutsideBar, false)
        XCTAssertEqual(config.chartOrientation, "vertical")
        XCTAssertEqual(config.plotReservedSpacePercent, 50)
    }

    func test_frontmatter_widthHeight() {
        let yaml = """
        ---
        config:
          xyChart:
            width: 900
            height: 600
        ---
        xychart
        line [1, 2, 3]
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        XCTAssertNotNil(fm)
        let config = fm?.perDiagram.xyChart.config
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.width, 900)
        XCTAssertEqual(config?.height, 600)
    }

    func test_frontmatter_showDataLabel() {
        let yaml = """
        ---
        config:
          xyChart:
            showDataLabel: true
        ---
        xychart
        line [1, 2, 3]
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        XCTAssertNotNil(fm)
        let config = fm?.perDiagram.xyChart.config
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.showDataLabel, true)
    }

    func test_frontmatter_orientation_horizontal() {
        let yaml = """
        ---
        config:
          xyChart:
            chartOrientation: horizontal
        ---
        xychart
        line [1, 2, 3]
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        XCTAssertNotNil(fm)
        let config = fm?.perDiagram.xyChart.config
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.chartOrientation, "horizontal")
    }

    func test_frontmatter_axisShowTick_false() {
        let yaml = """
        ---
        config:
          xyChart:
            xAxis:
              showTick: false
        ---
        xychart
        line [1, 2, 3]
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        XCTAssertNotNil(fm)
        let config = fm?.perDiagram.xyChart.config
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.xAxis.showTick, false)
    }

    func test_frontmatter_axisShowAxisLine_false() {
        let yaml = """
        ---
        config:
          xyChart:
            yAxis:
              showAxisLine: false
        ---
        xychart
        line [1, 2, 3]
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        XCTAssertNotNil(fm)
        let config = fm?.perDiagram.xyChart.config
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.yAxis.showAxisLine, false)
    }

    func test_frontmatter_plotReservedSpacePercent() {
        let yaml = """
        ---
        config:
          xyChart:
            plotReservedSpacePercent: 60
        ---
        xychart
        line [1, 2, 3]
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        XCTAssertNotNil(fm)
        let config = fm?.perDiagram.xyChart.config
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.plotReservedSpacePercent, 60)
    }

    func test_frontmatter_allConfigFields() {
        let yaml = """
        ---
        config:
          xyChart:
            width: 800
            height: 600
            titleFontSize: 18
            titlePadding: 15
            showTitle: false
            showDataLabel: true
            showDataLabelOutsideBar: true
            plotReservedSpacePercent: 60
            xAxis:
              showLabel: false
              labelFontSize: 12
              showTick: false
            yAxis:
              showTick: false
              showAxisLine: false
        ---
        xychart
        line [1, 2, 3]
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        XCTAssertNotNil(fm)
        let config = fm?.perDiagram.xyChart.config
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.width, 800)
        XCTAssertEqual(config?.height, 600)
        XCTAssertEqual(config?.titleFontSize, 18)
        XCTAssertEqual(config?.titlePadding, 15)
        XCTAssertEqual(config?.showTitle, false)
        XCTAssertEqual(config?.showDataLabel, true)
        XCTAssertEqual(config?.showDataLabelOutsideBar, true)
        XCTAssertEqual(config?.plotReservedSpacePercent, 60)
        XCTAssertEqual(config?.xAxis.showLabel, false)
        XCTAssertEqual(config?.xAxis.labelFontSize, 12)
        XCTAssertEqual(config?.xAxis.showTick, false)
        XCTAssertEqual(config?.yAxis.showTick, false)
        XCTAssertEqual(config?.yAxis.showAxisLine, false)
    }
}
