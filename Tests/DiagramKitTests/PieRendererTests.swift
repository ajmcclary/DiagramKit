import XCTest
import CoreGraphics
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

#if targetEnvironment(macCatalyst) || canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class PieRendererTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n").map(String.init)
    }

    private func defaultColors() -> DiagramColors {
        DiagramColors(bg: "#FFFFFF", fg: "#27272A")
    }

    // MARK: - SVG structure

    func testSvgRootElement() throws {
        let svg = try renderPieSVG("pie\n\"A\": 100")
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("</svg>"))
        XCTAssertTrue(svg.contains("viewBox"))
    }

    func testOuterCircleElement() throws {
        let svg = try renderPieSVG("pie\n\"A\": 100")
        XCTAssertTrue(svg.contains("pieOuterCircle"))
        XCTAssertTrue(svg.contains("<circle"))
    }

    func testPieArcs() throws {
        let svg = try renderPieSVG("pie\n\"A\": 100\n\"B\": 50")
        XCTAssertTrue(svg.contains("<path"))
    }

    func testSliceLabels() throws {
        let svg = try renderPieSVG("pie\n\"A\": 100\n\"B\": 50")
        XCTAssertTrue(svg.contains(#"class="slice""#))
    }

    func testTitleElement() throws {
        let svg = try renderPieSVG("pie title My Chart\n\"A\": 100")
        XCTAssertTrue(svg.contains(#"class="pieTitleText""#))
        XCTAssertTrue(svg.contains("My Chart"))
    }

    func testNoTitleWhenAbsent() throws {
        let svg = try renderPieSVG("pie\n\"A\": 100")
        // No <text class="pieTitleText"> element (only in CSS style)
        let classOccurrences = svg.ranges(of: #"class="pieTitleText""#).count
        XCTAssertEqual(classOccurrences, 0, "No element should have class pieTitleText when no title")
    }

    func testLegendPresent() throws {
        let svg = try renderPieSVG("pie\n\"A\": 100\n\"B\": 50")
        XCTAssertTrue(svg.contains("legend"))
        XCTAssertTrue(svg.contains("<rect"))
    }

    func testLegendWithShowData() throws {
        let svg = try renderPieSVG("pie showData\n\"A\": 60\n\"B\": 40")
        XCTAssertTrue(svg.contains("[60]"))
        XCTAssertTrue(svg.contains("[40]"))
    }

    func testLegendTextYPosition() throws {
        let svg = try renderPieSVG("pie\n\"A\": 100\n\"B\": 50")
        let legendElements = svg.components(separatedBy: "<g class=\"legend\">").last ?? ""
        XCTAssertTrue(legendElements.contains("y=\"14\"") || legendElements.contains("y=\"14"), "Legend text should have y=14 matching Mermaid")
    }

    // MARK: - Hidden slices

    func testHiddenSlicesNotInSvg() throws {
        let svg = try renderPieSVG("pie\n\"A\": 100\n\"B\": 0")
        let pathMatches = svg.ranges(of: "<path").count
        XCTAssertLessThanOrEqual(pathMatches, 1, "Should have at most 1 path element")
    }

    func testLegendIncludesHiddenSections() throws {
        let svg = try renderPieSVG("pie\n\"A\": 100\n\"B\": 0")
        XCTAssertTrue(svg.contains(">A<") || svg.contains("A ["), "Legend should include A")
        XCTAssertTrue(svg.contains(">B<") || svg.contains("B ["), "Legend should include B")
    }

    // MARK: - Accessibility

    func testAccessibilityTitle() throws {
        let svg = try renderPieSVG("pie\naccTitle: Test Chart\n\"A\": 100")
        XCTAssertTrue(svg.contains("<title>"))
        XCTAssertTrue(svg.contains("Test Chart"))
    }

    func testAccessibilityDescr() throws {
        let svg = try renderPieSVG("pie\naccDescr: A test description\n\"A\": 100")
        XCTAssertTrue(svg.contains("<desc>"))
        XCTAssertTrue(svg.contains("A test description"))
    }

    // MARK: - useMaxWidth

    func testUseMaxWidthEnabled() throws {
        let chart = PieChart(
            sections: [PieSection(label: "A", value: 100)],
            config: PieChartConfig(useMaxWidth: true)
        )
        let positioned = layoutPieChart(chart)
        let svg = renderPieSvg(positioned, defaultColors())

        XCTAssertTrue(svg.contains("width=\"100%\""), "useMaxWidth true should produce width=100%")
        XCTAssertTrue(svg.contains("max-width:"), "useMaxWidth true should produce max-width style")
    }

    func testUseMaxWidthDisabled() throws {
        let chart = PieChart(
            sections: [PieSection(label: "A", value: 100)],
            config: PieChartConfig(useMaxWidth: false)
        )
        let positioned = layoutPieChart(chart)
        let svg = renderPieSvg(positioned, defaultColors())

        XCTAssertFalse(svg.contains("width=\"100%\""), "useMaxWidth false should NOT produce width=100%")
        XCTAssertTrue(svg.contains("height=\"450\""), "useMaxWidth false should produce explicit height")
        XCTAssertFalse(svg.contains("max-width:"), "useMaxWidth false should NOT produce max-width style")
    }

    // MARK: - Theme/config parity

    func testFlatThemeVariablesApplyToParserModel() throws {
        let source = """
        ---
        config:
          themeVariables:
            pie1: "#AA0000"
            pieOuterStrokeWidth: "5px"
            pieLegendTextColor: "#222222"
        ---
        pie
        "A": 100
        """

        let graph = try DiagramPipeline.parse(source)
        guard case .pie(let chart) = graph.payload else {
            XCTFail("Expected pie chart payload")
            return
        }

        XCTAssertEqual(chart.theme.pie1, "#AA0000")
        XCTAssertEqual(chart.theme.pieOuterStrokeWidth, "5px")
        XCTAssertEqual(chart.theme.pieLegendTextColor, "#222222")
    }

    func testSvgUsesNegativeViewBoxOriginForLongTitle() throws {
        let title = String(repeating: "Long title ", count: 20)
        let (chart, _) = try parsePieChart(lines("pie title \(title)\n\"A\": 100"))
        var positioned = layoutPieChart(chart)
        positioned.config.useMaxWidth = false
        let svg = renderPieSvg(positioned, defaultColors())

        XCTAssertTrue(svg.contains(#"viewBox="-"#), "Expected negative viewBox origin for long title")
    }

    func testSvgEmitsConcreteThemeColorsAndStrokeStyles() throws {
        let chart = PieChart(
            sections: [
                PieSection(label: "A", value: 60),
                PieSection(label: "B", value: 40),
            ],
            diagramTitle: "Theme",
            theme: PieChartThemeConfig(
                pie1: "#AA0000",
                pie2: "#00AA00",
                pieTitleTextColor: "#333333",
                pieSectionTextColor: "#111111",
                pieLegendTextColor: "#222222",
                pieStrokeColor: "#123456",
                pieStrokeWidth: "3px",
                pieOuterStrokeWidth: "5px",
                pieOuterStrokeColor: "#654321",
                pieOpacity: "0.9",
                fontFamily: "Arial"
            )
        )
        let svg = renderPieSvg(layoutPieChart(chart), defaultColors())

        XCTAssertTrue(svg.contains("fill=\"#AA0000\""))
        XCTAssertTrue(svg.contains("fill=\"#00AA00\""))
        XCTAssertTrue(svg.contains("stroke: #123456"))
        XCTAssertTrue(svg.contains("stroke-width : 3px"))
        XCTAssertTrue(svg.contains("stroke: #654321"))
        XCTAssertTrue(svg.contains("stroke-width: 5px"))
        XCTAssertTrue(svg.contains("fill: #111111"))
        XCTAssertTrue(svg.contains("fill: #222222"))
        XCTAssertTrue(svg.contains("fill: #333333"))
        XCTAssertTrue(svg.contains("font-family: Arial"))
    }

    func testSvgColorWrappingBeyondTwelveUsesPiePaletteModulo() throws {
        var sections: [PieSection] = []
        for i in 1...14 {
            sections.append(PieSection(label: "S\(i)", value: 100))
        }
        let chart = PieChart(
            sections: sections,
            theme: PieChartThemeConfig(
                pie1: "#111111",
                pie2: "#222222",
                pie3: "#333333",
                pie4: "#444444",
                pie5: "#555555",
                pie6: "#666666",
                pie7: "#777777",
                pie8: "#888888",
                pie9: "#999999",
                pie10: "#AAAAAA",
                pie11: "#BBBBBB",
                pie12: "#CCCCCC"
            )
        )
        let svg = renderPieSvg(layoutPieChart(chart), defaultColors())

        XCTAssertGreaterThanOrEqual(svg.ranges(of: "fill=\"#111111\"").count, 2)
        XCTAssertGreaterThanOrEqual(svg.ranges(of: "fill=\"#222222\"").count, 2)
    }

    func testCoreGraphicsUsesPieThemeSliceColor() throws {
        let chart = PieChart(
            sections: [PieSection(label: "A", value: 100)],
            theme: PieChartThemeConfig(
                pie1: "#FF0000",
                pieStrokeWidth: "0px",
                pieOuterStrokeWidth: "0px",
                pieOpacity: "1"
            )
        )
        let positionedPie = layoutPieChart(chart)
        let graph = DiagramDocument(payload: .pie(chart))
        let positioned = PositionedGraph(
            diagram: graph,
            width: positionedPie.width,
            height: positionedPie.height,
            content: .pie(positionedPie)
        )

        var pixels = [UInt8](repeating: 0, count: 450 * 450 * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixels,
            width: 450,
            height: 450,
            bitsPerComponent: 8,
            bytesPerRow: 450 * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let context else {
            XCTFail("Expected bitmap context")
            return
        }

        DiagramRenderer().render(positioned, in: context, bounds: CGRect(x: 0, y: 0, width: 450, height: 450))

        let center = ((225 * 450) + 225) * 4
        XCTAssertGreaterThan(pixels[center], 220)
        XCTAssertLessThan(pixels[center + 1], 40)
        XCTAssertLessThan(pixels[center + 2], 40)
    }

    func testCoreGraphicsPieTitleDrawsUprightInImageRendererCoordinateSystem() throws {
        let title = "My Chart"
        let rendered = try renderPiePixels("pie title \(title)\n\"A\": 50\n\"B\": 50")

        let template = renderTitleTemplatePixels(title, width: rendered.width, height: rendered.height)
        let xRange = 90..<360
        let yRange = 0..<38
        let uprightDifference = pixelDifference(
            rendered.pixels,
            template,
            width: rendered.width,
            xRange: xRange,
            yRange: yRange,
            flipTemplateVertically: false
        )
        let flippedDifference = pixelDifference(
            rendered.pixels,
            template,
            width: rendered.width,
            xRange: xRange,
            yRange: yRange,
            flipTemplateVertically: true
        )

        XCTAssertLessThan(
            uprightDifference,
            flippedDifference,
            "The pie title should match the shared upright text renderer more closely than a vertically flipped copy"
        )
    }

    // MARK: - CSS classes

    func testCssClasses() throws {
        let svg = try renderPieSVG("pie\n\"A\": 100")
        XCTAssertTrue(svg.contains(".pieCircle"))
        XCTAssertTrue(svg.contains(".pieOuterCircle"))
        XCTAssertTrue(svg.contains(".pieTitleText"))
        XCTAssertTrue(svg.contains(".slice"))
    }

    // MARK: - Group transform

    func testGroupTransform() throws {
        let svg = try renderPieSVG("pie\n\"A\": 100")
        XCTAssertTrue(svg.contains(#"translate(225"#))
    }

    // MARK: - Zero-sum edge cases

    func testZeroSumRendersWithoutNaNs() throws {
        let svg = try renderPieSVG("pie\n\"A\": 0\n\"B\": 0")
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("</svg>"))
        XCTAssertFalse(svg.contains("NaN"))
        XCTAssertFalse(svg.contains("nan"))
    }

    func testHeaderOnlyRendersValidSvg() throws {
        let svg = try renderPieSVG("pie")
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("</svg>"))
        XCTAssertFalse(svg.contains("NaN"))
    }

    // MARK: - Convenience helper

    private func renderPieSVG(_ source: String) throws -> String {
        let (chart, _) = try parsePieChart(lines(source))
        let positioned = layoutPieChart(chart)
        return renderPieSvg(positioned, defaultColors())
    }

    private func renderPiePixels(_ source: String) throws -> (pixels: [UInt8], width: Int, height: Int) {
        let (chart, _) = try parsePieChart(lines(source))
        let positionedPie = layoutPieChart(chart)
        let graph = DiagramDocument(payload: .pie(chart))
        let positioned = PositionedGraph(
            diagram: graph,
            width: positionedPie.width,
            height: positionedPie.height,
            content: .pie(positionedPie)
        )

        let width = Int(ceil(positionedPie.width))
        let height = Int(ceil(positionedPie.height))
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        )
        guard let context else {
            XCTFail("Expected bitmap context")
            return (pixels, width, height)
        }

        context.setFillColor(BMColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        DiagramRenderer().render(positioned, in: context, bounds: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        return (pixels, width, height)
    }

    private func renderTitleTemplatePixels(_ title: String, width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        )
        guard let context else { return pixels }

        context.setFillColor(BMColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        LabelRenderer().drawText(
            title,
            at: CGPoint(x: 225, y: 25),
            context: context,
            color: BMColor.black,
            font: testPieFont(size: 25),
            alignment: .center
        )
        return pixels
    }

    private func pixelDifference(
        _ actual: [UInt8],
        _ template: [UInt8],
        width: Int,
        xRange: Range<Int>,
        yRange: Range<Int>,
        flipTemplateVertically: Bool
    ) -> UInt64 {
        var difference: UInt64 = 0
        for y in yRange {
            let templateY = flipTemplateVertically ? (yRange.upperBound - 1 - (y - yRange.lowerBound)) : y
            for x in xRange {
                let actualIndex = (y * width + x) * 4
                let templateIndex = (templateY * width + x) * 4
                for channel in 0..<3 {
                    difference += UInt64(abs(Int(actual[actualIndex + channel]) - Int(template[templateIndex + channel])))
                }
            }
        }
        return difference
    }

    private func testPieFont(size: CGFloat) -> BMFont {
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        return UIFont.systemFont(ofSize: size)
        #elseif canImport(AppKit)
        return NSFont.systemFont(ofSize: size)
        #endif
    }
}
