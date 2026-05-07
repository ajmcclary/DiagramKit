import XCTest
import CoreGraphics
@testable import BeautifulMermaid

final class QuadrantRendererTests: XCTestCase {

    // MARK: - Quadrant fill rendering

    func testQuadrantFillsDrawInCorrectRegions() throws {
        let theme = QuadrantChartThemeConfig(
            quadrant1Fill: "#FF0000",
            quadrant2Fill: "#00FF00",
            quadrant3Fill: "#0000FF",
            quadrant4Fill: "#FFFF00",
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
            quadrantTitleFill: "#FFFFFF"
        )
        let chart = QuadrantChart(
            config: QuadrantChartConfig(
                chartWidth: 400,
                chartHeight: 400,
                showXAxis: false,
                showYAxis: false,
                showTitle: false
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

        let width = 400
        let height = 400
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = makeContext(width: width, height: height, pixels: &pixels)
        guard let context else { XCTFail("Expected bitmap context"); return }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        DiagramRenderer().render(positioned, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))

        let topRightRed = countMatchingPixels(in: pixels, width: width, xRange: 220..<380, yRange: 20..<180, r: 255, g: 0, b: 0)
        let topLeftGreen = countMatchingPixels(in: pixels, width: width, xRange: 20..<180, yRange: 20..<180, r: 0, g: 255, b: 0)
        let bottomLeftBlue = countMatchingPixels(in: pixels, width: width, xRange: 20..<180, yRange: 220..<380, r: 0, g: 0, b: 255)
        let bottomRightYellow = countMatchingPixels(in: pixels, width: width, xRange: 220..<380, yRange: 220..<380, r: 255, g: 255, b: 0)

        XCTAssertGreaterThan(topRightRed, 100, "Top-right quadrant should have red fill")
        XCTAssertGreaterThan(topLeftGreen, 100, "Top-left quadrant should have green fill")
        XCTAssertGreaterThan(bottomLeftBlue, 100, "Bottom-left quadrant should have blue fill")
        XCTAssertGreaterThan(bottomRightYellow, 100, "Bottom-right quadrant should have yellow fill")
    }

    // MARK: - Point rendering

    func testPointsDrawAtExpectedCoordinates() throws {
        var chart = QuadrantChart(
            config: QuadrantChartConfig(
                chartWidth: 400,
                chartHeight: 400,
                showXAxis: false,
                showYAxis: false,
                showTitle: false
            )
        )
        chart.points = [QuadrantPoint(text: "A", x: 0.25, y: 0.25, radius: 8, color: "#FF0000")]
        let positionedQuadrant = layoutQuadrantChart(chart)
        let positioned = PositionedGraph(
            diagram: MermaidGraph(payload: .quadrantChart(chart)),
            width: positionedQuadrant.width,
            height: positionedQuadrant.height,
            content: .quadrantChart(positionedQuadrant)
        )

        let width = 400
        let height = 400
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = makeContext(width: width, height: height, pixels: &pixels)
        guard let context else { XCTFail("Expected bitmap context"); return }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        DiagramRenderer().render(positioned, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))

        let bottomLeftRedPixels = countMatchingPixels(in: pixels, width: width, xRange: 40..<160, yRange: 240..<360, r: 255, g: 0, b: 0)
        let topRightRedPixels = countMatchingPixels(in: pixels, width: width, xRange: 240..<360, yRange: 40..<160, r: 255, g: 0, b: 0)

        XCTAssertGreaterThan(bottomLeftRedPixels, 10, "Point at [0.25, 0.25] should appear in bottom-left region")
        XCTAssertLessThan(topRightRedPixels, 5, "Point should not appear in top-right region")
    }

    func testPointZOrderMatchesMermaidPrepend() throws {
        var chart = QuadrantChart(
            config: QuadrantChartConfig(
                chartWidth: 400,
                chartHeight: 400,
                showXAxis: false,
                showYAxis: false,
                showTitle: false
            )
        )
        chart.points = [
            QuadrantPoint(text: "Bottom", x: 0.5, y: 0.5, radius: 15, color: "#0000FF"),
            QuadrantPoint(text: "Middle", x: 0.5, y: 0.5, radius: 12, color: "#00FF00"),
            QuadrantPoint(text: "Top", x: 0.5, y: 0.5, radius: 9, color: "#FF0000"),
        ]
        let positionedQuadrant = layoutQuadrantChart(chart)
        let positioned = PositionedGraph(
            diagram: MermaidGraph(payload: .quadrantChart(chart)),
            width: positionedQuadrant.width,
            height: positionedQuadrant.height,
            content: .quadrantChart(positionedQuadrant)
        )

        let width = 400
        let height = 400
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = makeContext(width: width, height: height, pixels: &pixels)
        guard let context else { XCTFail("Expected bitmap context"); return }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        DiagramRenderer().render(positioned, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))

        let centerRedPixels = countMatchingPixels(in: pixels, width: width, xRange: 185..<215, yRange: 185..<215, r: 255, g: 0, b: 0)
        let centerBluePixels = countMatchingPixels(in: pixels, width: width, xRange: 185..<215, yRange: 185..<215, r: 0, g: 0, b: 255)

        XCTAssertGreaterThan(centerRedPixels, 10, "First-inserted point (top in z-order) should be visible at center as red")
        XCTAssertLessThan(centerBluePixels, centerRedPixels, "Later-inserted point (bottom in z-order) should be mostly occluded")
    }

    // MARK: - Border rendering

    func testBordersDrawSixLines() throws {
        let chart = QuadrantChart(
            config: QuadrantChartConfig(
                chartWidth: 400,
                chartHeight: 400,
                showXAxis: false,
                showYAxis: false,
                showTitle: false
            )
        )
        let positionedQuadrant = layoutQuadrantChart(chart)
        let positioned = PositionedGraph(
            diagram: MermaidGraph(payload: .quadrantChart(chart)),
            width: positionedQuadrant.width,
            height: positionedQuadrant.height,
            content: .quadrantChart(positionedQuadrant)
        )

        let width = 400
        let height = 400
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = makeContext(width: width, height: height, pixels: &pixels)
        guard let context else { XCTFail("Expected bitmap context"); return }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        DiagramRenderer().render(positioned, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))

        let borderColoredPixels = countColoredPixels(in: pixels, width: width, xRange: 0..<400, yRange: 0..<400)
        XCTAssertGreaterThan(borderColoredPixels, 100, "Border lines should produce colored pixels across the chart")
    }

    // MARK: - Y-axis position

    func testYAxisRightRendersOnRightSide() throws {
        let chart = QuadrantChart(
            yAxisBottomText: "BOTTOM",
            config: QuadrantChartConfig(
                chartWidth: 400,
                chartHeight: 400,
                yAxisPosition: "right",
                showXAxis: false,
                showYAxis: true,
                showTitle: false
            )
        )
        let positionedQuadrant = layoutQuadrantChart(chart)
        let positioned = PositionedGraph(
            diagram: MermaidGraph(payload: .quadrantChart(chart)),
            width: positionedQuadrant.width,
            height: positionedQuadrant.height,
            content: .quadrantChart(positionedQuadrant)
        )

        let width = 400
        let height = 400
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = makeContext(width: width, height: height, pixels: &pixels)
        guard let context else { XCTFail("Expected bitmap context"); return }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        DiagramRenderer().render(positioned, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))

        let leftSideDark = countDarkPixels(in: pixels, width: width, xRange: 0..<50, yRange: 0..<400)
        let rightSideDark = countDarkPixels(in: pixels, width: width, xRange: 350..<400, yRange: 0..<400)

        XCTAssertGreaterThan(rightSideDark, 5, "Y-axis label should render on right side")
        XCTAssertTrue(rightSideDark > leftSideDark, "Y-axis label should have more dark pixels on right than left")
    }

    func testYAxisLeftRendersOnLeftSide() throws {
        let chart = QuadrantChart(
            yAxisBottomText: "BOTTOM",
            config: QuadrantChartConfig(
                chartWidth: 400,
                chartHeight: 400,
                yAxisPosition: "left",
                showXAxis: false,
                showYAxis: true,
                showTitle: false
            )
        )
        let positionedQuadrant = layoutQuadrantChart(chart)
        let positioned = PositionedGraph(
            diagram: MermaidGraph(payload: .quadrantChart(chart)),
            width: positionedQuadrant.width,
            height: positionedQuadrant.height,
            content: .quadrantChart(positionedQuadrant)
        )

        let width = 400
        let height = 400
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = makeContext(width: width, height: height, pixels: &pixels)
        guard let context else { XCTFail("Expected bitmap context"); return }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        DiagramRenderer().render(positioned, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))

        let leftSideDark = countDarkPixels(in: pixels, width: width, xRange: 0..<50, yRange: 0..<400)
        let rightSideDark = countDarkPixels(in: pixels, width: width, xRange: 350..<400, yRange: 0..<400)

        XCTAssertGreaterThan(leftSideDark, 5, "Y-axis label should render on left side")
        XCTAssertTrue(leftSideDark > rightSideDark, "Y-axis label should have more dark pixels on left than right")
    }

    // MARK: - Point radius

    func testPointRadiusAffectsCircleSize() throws {
        let width = 400
        let height = 400

        var chartSmall = QuadrantChart(
            config: QuadrantChartConfig(
                chartWidth: Double(width),
                chartHeight: Double(height),
                pointRadius: 5,
                showXAxis: false,
                showYAxis: false,
                showTitle: false
            )
        )
        chartSmall.points = [QuadrantPoint(text: "A", x: 0.5, y: 0.5, color: "#FF0000")]

        var chartLarge = QuadrantChart(
            config: QuadrantChartConfig(
                chartWidth: Double(width),
                chartHeight: Double(height),
                pointRadius: 20,
                showXAxis: false,
                showYAxis: false,
                showTitle: false
            )
        )
        chartLarge.points = [QuadrantPoint(text: "A", x: 0.5, y: 0.5, color: "#FF0000")]

        let smallPX = layoutQuadrantChart(chartSmall)
        let largePX = layoutQuadrantChart(chartLarge)

        let positionedSmall = PositionedGraph(diagram: MermaidGraph(payload: .quadrantChart(chartSmall)), width: smallPX.width, height: smallPX.height, content: .quadrantChart(smallPX))
        let positionedLarge = PositionedGraph(diagram: MermaidGraph(payload: .quadrantChart(chartLarge)), width: largePX.width, height: largePX.height, content: .quadrantChart(largePX))

        var smallPixels = [UInt8](repeating: 0, count: width * height * 4)
        var largePixels = [UInt8](repeating: 0, count: width * height * 4)

        let smallCtx = makeContext(width: width, height: height, pixels: &smallPixels)
        let largeCtx = makeContext(width: width, height: height, pixels: &largePixels)
        guard let smallCtx, let largeCtx else { XCTFail("Expected bitmap contexts"); return }

        smallCtx.translateBy(x: 0, y: CGFloat(height))
        smallCtx.scaleBy(x: 1, y: -1)
        largeCtx.translateBy(x: 0, y: CGFloat(height))
        largeCtx.scaleBy(x: 1, y: -1)

        DiagramRenderer().render(positionedSmall, in: smallCtx, bounds: CGRect(x: 0, y: 0, width: width, height: height))
        DiagramRenderer().render(positionedLarge, in: largeCtx, bounds: CGRect(x: 0, y: 0, width: width, height: height))

        let smallRedPixels = countMatchingPixels(in: smallPixels, width: width, xRange: 180..<220, yRange: 180..<220, r: 255, g: 0, b: 0)
        let largeRedPixels = countMatchingPixels(in: largePixels, width: width, xRange: 180..<220, yRange: 180..<220, r: 255, g: 0, b: 0)

        XCTAssertGreaterThan(largeRedPixels, smallRedPixels, "Larger radius point should occupy more pixels than smaller radius point")
    }

    // MARK: - Title visibility

    func testTitleAbsentWhenShowTitleFalse() throws {
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
            titleText: "HIDDEN TITLE",
            config: QuadrantChartConfig(
                chartWidth: 300,
                chartHeight: 300,
                showXAxis: false,
                showYAxis: false,
                showTitle: false
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
        let context = makeContext(width: width, height: height, pixels: &pixels)
        guard let context else { XCTFail("Expected bitmap context"); return }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        DiagramRenderer().render(positioned, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))

        let topDarkPixels = countDarkPixels(in: pixels, width: width, xRange: 40..<260, yRange: 0..<50)
        XCTAssertLessThan(topDarkPixels, 10, "Title should not render when showTitle is false")
    }

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

    private func countMatchingPixels(
        in pixels: [UInt8],
        width: Int,
        xRange: Range<Int>,
        yRange: Range<Int>,
        r: UInt8,
        g: UInt8,
        b: UInt8
    ) -> Int {
        var count = 0
        for y in yRange {
            for x in xRange {
                let index = ((y * width) + x) * 4
                let red = pixels[index]
                let green = pixels[index + 1]
                let blue = pixels[index + 2]
                let alpha = pixels[index + 3]
                let tolerance: UInt8 = 40
                if alpha > 0,
                   abs(Int(red) - Int(r)) < Int(tolerance),
                   abs(Int(green) - Int(g)) < Int(tolerance),
                   abs(Int(blue) - Int(b)) < Int(tolerance) {
                    count += 1
                }
            }
        }
        return count
    }

    private func countColoredPixels(
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
                let isWhite = red > 240 && green > 240 && blue > 240
                if alpha > 0 && !isWhite {
                    count += 1
                }
            }
        }
        return count
    }

    private func makeContext(width: Int, height: Int, pixels: UnsafeMutablePointer<UInt8>) -> CGContext? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGContext(
            data: pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    // MARK: - Visual snapshot integration (renders all playground examples)

    struct QuadrantSnapshotEntry: Codable {
        let id: String
        let source: String
    }

    struct QuadrantSnapshotsFile: Codable {
        let diagrams: [QuadrantSnapshotEntry]
    }

    @MainActor
    func testRenderAllQuadrantPlaygroundExamplesWithoutCrash() async throws {
        try requireMermaidExporterTestsEnabled()

        let projectRoot = findProjectRoot()
        let jsonPath = (projectRoot as NSString).appendingPathComponent(
            "Examples/MermaidPlayground/Resources/test-diagrams.json"
        )
        try requireFixtureExists(atPath: jsonPath)

        let data = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        let decoded = try JSONDecoder().decode(QuadrantSnapshotsFile.self, from: data)

        let quadrantExamples = decoded.diagrams.filter { $0.id.hasPrefix("quadrant-") }

        for example in quadrantExamples {
            do {
                let graph = try MermaidParser.parse(example.source)
                let positioned = try GraphLayout().layout(graph)

                let width = 400
                let height = 400
                var pixels = [UInt8](repeating: 0, count: width * height * 4)
                guard let context = makeContext(width: width, height: height, pixels: &pixels) else {
                    XCTFail("Failed to create CGContext for \(example.id)")
                    continue
                }
                context.translateBy(x: 0, y: CGFloat(height))
                context.scaleBy(x: 1, y: -1)

                DiagramRenderer().render(
                    positioned,
                    in: context,
                    bounds: CGRect(x: 0, y: 0, width: width, height: height)
                )

                let totalDark = countDarkPixels(in: pixels, width: width, xRange: 0..<width, yRange: 0..<height)
                XCTAssertGreaterThan(totalDark, 10, "\(example.id) rendered image should have non-trivial dark pixels")
            } catch {
                XCTFail("Quadrant example \(example.id) failed to render: \(error)")
            }
        }
    }

    private func findProjectRoot() -> String {
        var dir = (URL(fileURLWithPath: #file).deletingLastPathComponent().path as NSString)
            .deletingLastPathComponent
        dir = (dir as NSString).deletingLastPathComponent
        if FileManager.default.fileExists(atPath: (dir as NSString).appendingPathComponent("Package.swift")) {
            return dir
        }
        return (FileManager.default.currentDirectoryPath as NSString).deletingLastPathComponent
    }
}
