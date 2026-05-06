import XCTest
import CoreGraphics
@testable import BeautifulMermaid

final class QuadrantRendererTests: XCTestCase {

    func testCoreGraphicsTitleDrawsAtPositionedTopY() throws {
        let theme = QuadrantChartThemeConfig(
            quadrant1Fill: "#FFFFFF",
            quadrant2Fill: "#FFFFFF",
            quadrant3Fill: "#FFFFFF",
            quadrant4Fill: "#FFFFFF",
            quadrant1TextFill: "#FFFFFF",
            quadrant2TextFill: "#FFFFFF",
            quadrant3TextFill: "#FFFFFF",
            quadrant4TextFill: "#FFFFFF",
            quadrantPointFill: "#FFFFFF",
            quadrantPointTextFill: "#FFFFFF",
            quadrantXAxisTextFill: "#FFFFFF",
            quadrantYAxisTextFill: "#FFFFFF",
            quadrantInternalBorderStrokeFill: "#FFFFFF",
            quadrantExternalBorderStrokeFill: "#FFFFFF",
            quadrantTitleFill: "#000000"
        )
        let chart = QuadrantChart(
            titleText: "TOP TITLE",
            config: QuadrantChartConfig(
                chartWidth: 300,
                chartHeight: 300,
                showXAxis: false,
                showYAxis: false,
                showTitle: true
            ),
            theme: theme
        )
        let positionedQuadrant = layoutQuadrantChart(chart)
        let positioned = PositionedGraph(
            diagram: MermaidGraph(payload: .quadrantChart(chart)),
            width: positionedQuadrant.width,
            height: positionedQuadrant.height,
            content: .quadrantChart(positionedQuadrant)
        )

        let width = 300
        let height = 300
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let context else {
            XCTFail("Expected bitmap context")
            return
        }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        DiagramRenderer().render(
            positioned,
            in: context,
            bounds: CGRect(x: 0, y: 0, width: width, height: height)
        )

        let topDarkPixels = countDarkPixels(in: pixels, width: width, xRange: 40..<260, yRange: 0..<50)
        let bottomDarkPixels = countDarkPixels(in: pixels, width: width, xRange: 40..<260, yRange: 250..<300)

        XCTAssertGreaterThan(topDarkPixels, 10, "Expected title text near the positioned top y coordinate")
        XCTAssertLessThan(bottomDarkPixels, topDarkPixels / 4, "Title should not be mirrored into the bottom band")
    }

    private func countDarkPixels(
        in pixels: [UInt8],
        width: Int,
        xRange: Range<Int>,
        yRange: Range<Int>
    ) -> Int {
        var count = 0
        for y in yRange {
            for x in xRange {
                let index = ((y * width) + x) * 4
                let red = pixels[index]
                let green = pixels[index + 1]
                let blue = pixels[index + 2]
                let alpha = pixels[index + 3]
                if alpha > 0 && red < 80 && green < 80 && blue < 80 {
                    count += 1
                }
            }
        }
        return count
    }
}
