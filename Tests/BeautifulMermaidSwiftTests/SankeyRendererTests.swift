import XCTest
import CoreGraphics
@testable import BeautifulMermaid

final class SankeyRendererTests: XCTestCase {

    func testParseDetectsSankeyType() async throws {
        let graph = try await MermaidRenderer.parse("sankey\nA,B,10")
        XCTAssertEqual(graph.type, .sankey)
        switch graph.payload {
        case .sankey(let diagram):
            XCTAssertEqual(diagram.links.count, 1)
        default:
            XCTFail("Expected sankey payload")
        }
    }

    func testParseDetectsSankeyBetaType() async throws {
        let graph = try await MermaidRenderer.parse("sankey-beta\nA,B,10")
        XCTAssertEqual(graph.type, .sankey)
    }

    func testLayoutProducesSankeyContent() async throws {
        let positioned = try await MermaidRenderer.layout("sankey\nA,B,10")
        switch positioned.content {
        case .sankey(let diagram):
            XCTAssertEqual(diagram.nodes.count, 2)
            XCTAssertEqual(diagram.links.count, 1)
        default:
            XCTFail("Expected sankey positioned content")
        }
    }

    func testRenderSvgProducesOutput() async throws {
        let svg = try await MermaidRenderer.renderSVG(source: "sankey\nA,B,10")
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("</svg>"))
    }

    func testRenderSvgWithEnergyCsv() async throws {
        let source = """
        sankey
        Electricity grid,Over generation / exports,104.453
        Electricity grid,Heating and cooling - homes,113.726
        Electricity grid,H2 conversion,27.14
        Electricity grid,Industry,342.165
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertFalse(svg.isEmpty)
    }

    func testRenderSvgWithFrontmatter() async throws {
        let source = """
        ---
        config:
          sankey:
            showValues: false
            labelStyle: outlined
        ---
        sankey
        A,B,10
        B,C,20
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("</svg>"))
    }

    func testRenderSvgWithCustomColors() async throws {
        let source = """
        ---
        config:
          sankey:
            nodeColors:
              A: "#4e79a7"
              B: "#e15759"
        ---
        sankey
        A,B,10
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("#4e79a7") || svg.contains("#e15759"))
    }

    func testRenderSvgWithQuotedNodeColorKey() async throws {
        let source = """
        ---
        config:
          sankey:
            nodeColors:
              "Electricity grid": "#123456"
        ---
        sankey
        Electricity grid,Industry,10
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains(##"fill="#123456""##))
    }

    func testRenderSvgScopesIdsAcrossSankeyRenders() async throws {
        let first = try await MermaidRenderer.renderSVG(source: "sankey\nA,B,10")
        let second = try await MermaidRenderer.renderSVG(source: "sankey\nA,B,10")

        let firstIDs = Set(Self.svgIDs(in: first).filter { $0.contains("node-") || $0.contains("linearGradient-") })
        let secondIDs = Set(Self.svgIDs(in: second).filter { $0.contains("node-") || $0.contains("linearGradient-") })

        XCTAssertFalse(firstIDs.isEmpty)
        XCTAssertFalse(secondIDs.isEmpty)
        XCTAssertTrue(firstIDs.isDisjoint(with: secondIDs), "Sankey node/gradient ids should be scoped per render")
    }

    func testAsciiDetectionReturnsSankey() {
        let detected = original_src_ascii_index.detectDiagramType("sankey\nA,B,10")
        XCTAssertEqual(detected, "sankey")
    }

    func testDiagramTypeAllCasesIncludesSankey() {
        XCTAssertTrue(DiagramType.allCases.contains(.sankey), "DiagramType.allCases should include .sankey")
    }

    func testPositionedGraphSankeyAccessor() async throws {
        let positioned = try await MermaidRenderer.layout("sankey\nA,B,10")
        XCTAssertNotNil(positioned.sankeyData)
    }

    func testPositionedGraphIncludesDefaultSankeySvgPadding() async throws {
        let positioned = try await MermaidRenderer.layout("sankey\nA,B,10")
        XCTAssertEqual(positioned.width, 620, accuracy: 0.01)
        XCTAssertEqual(positioned.height, 420, accuracy: 0.01)
    }

    func testCoreGraphicsSankeyLinkUsesTopDownCoordinates() {
        let config = SankeyDiagramConfig(
            width: 120,
            height: 100,
            linkColor: .fixed("#ff0000"),
            showValues: false
        )
        let diagram = PositionedSankeyDiagram(
            width: 120,
            height: 100,
            nodes: [
                PositionedSankeyNode(id: "A", x0: 0, x1: 10, y0: 15, y1: 35, value: 10, layer: 0),
                PositionedSankeyNode(id: "B", x0: 110, x1: 120, y0: 15, y1: 35, value: 10, layer: 1),
            ],
            links: [
                PositionedSankeyLink(
                    sourceID: "A",
                    targetID: "B",
                    value: 10,
                    width: 10,
                    y0: 20,
                    y1: 30,
                    path: SankeyLinkPath(
                        sourceX: 10,
                        sourceY: 25,
                        targetX: 110,
                        targetY: 25,
                        controlPoints: [CGPoint(x: 60, y: 25), CGPoint(x: 60, y: 25)]
                    )
                )
            ],
            config: config
        )
        let positioned = PositionedGraph(
            diagram: MermaidGraph(payload: .sankey(SankeyDiagram(config: config))),
            width: 120,
            height: 100,
            content: .sankey(diagram)
        )

        let width = 120
        let height = 100
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
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
            return
        }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        DiagramRenderer(theme: DiagramTheme(background: BMColor.white, foreground: BMColor.black)).render(
            positioned,
            in: context,
            bounds: CGRect(x: 0, y: 0, width: width, height: height)
        )

        let expectedLinkPixel = Self.pixel(in: pixels, width: width, x: 60, y: 25)
        let flippedLinkPixel = Self.pixel(in: pixels, width: width, x: 60, y: 75)
        XCTAssertGreaterThan(expectedLinkPixel.red, 180, "Link should render at its layout y coordinate")
        XCTAssertLessThan(expectedLinkPixel.green, 180, "Link should render at its layout y coordinate")
        XCTAssertLessThan(expectedLinkPixel.blue, 180, "Link should render at its layout y coordinate")
        XCTAssertGreaterThan(flippedLinkPixel.green, 220, "Link should not be vertically flipped")
        XCTAssertGreaterThan(flippedLinkPixel.blue, 220, "Link should not be vertically flipped")
    }

    func testMultilineSankeyLabelsAnchorAtRequestedPoint() {
        let width = 180
        let height = 120
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
            return
        }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        let renderer = DiagramRenderer(theme: DiagramTheme(background: BMColor.white, foreground: BMColor.black))
        renderer._drawTextInFlipped(
            "A\n10",
            at: CGPoint(x: 24, y: 60),
            context: context,
            contentHeight: CGFloat(height),
            color: BMColor.black,
            font: RenderConfig.shared.proportionalFont(size: 14),
            alignment: .left
        )

        XCTAssertGreaterThan(
            Self.countDarkPixels(in: pixels, width: width, xRange: 20..<70, yRange: 40..<82),
            5,
            "Left-aligned multiline labels should draw near the requested anchor, not hundreds of points away."
        )
    }

    func testRenderSvgWithLinkColorSource() async throws {
        let source = """
        ---
        config:
          sankey:
            linkColor: source
        ---
        sankey
        A,B,10
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("</svg>"))
    }

    func testRenderSvgWithLinkColorTarget() async throws {
        let source = """
        ---
        config:
          sankey:
            linkColor: target
        ---
        sankey
        A,B,10
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("</svg>"))
    }

    func testRenderSvgWithFixedLinkColor() async throws {
        let source = """
        ---
        config:
          sankey:
            linkColor: "#ff0000"
        ---
        sankey
        A,B,10
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("</svg>"))
    }

    private static func svgIDs(in svg: String) -> [String] {
        let pattern = #"id="([^"]+)""#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(svg.startIndex..<svg.endIndex, in: svg)
        return regex.matches(in: svg, range: range).compactMap { match in
            guard let idRange = Range(match.range(at: 1), in: svg) else { return nil }
            return String(svg[idRange])
        }
    }

    private static func pixel(in pixels: [UInt8], width: Int, x: Int, y: Int) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let offset = (y * width + x) * 4
        return (pixels[offset], pixels[offset + 1], pixels[offset + 2], pixels[offset + 3])
    }

    private static func countDarkPixels(in pixels: [UInt8], width: Int, xRange: Range<Int>, yRange: Range<Int>) -> Int {
        var count = 0
        for y in yRange {
            for x in xRange {
                let pixel = Self.pixel(in: pixels, width: width, x: x, y: y)
                if pixel.red < 180, pixel.green < 180, pixel.blue < 180, pixel.alpha > 0 {
                    count += 1
                }
            }
        }
        return count
    }
}
