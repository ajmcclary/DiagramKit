import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class PacketSvgTests: XCTestCase {

    private func parseAndRender(_ source: String, theme: PacketThemeConfig = .default) throws -> String {
        let lines = _mermaidSourceLines(from: source)
        let diagram = try parsePacketDiagram(lines, frontmatter: nil)
        // default title precedence
        let positioned = layoutPacketDiagram(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#000000")
        return renderPacketSvg(positioned, colors, "Inter", false, theme: theme)
    }

    private func firstDouble(in text: String, after prefix: String) throws -> Double {
        guard let range = text.range(of: prefix) else {
            XCTFail("Missing prefix: \(prefix)")
            throw NSError(domain: "PacketSvgTests", code: 1)
        }
        let remainder = text[range.upperBound...]
        let value = remainder.prefix { $0.isNumber || $0 == "." || $0 == "-" }
        guard let double = Double(value) else {
            XCTFail("Missing numeric value after prefix: \(prefix)")
            throw NSError(domain: "PacketSvgTests", code: 2)
        }
        return double
    }

    func testSvgViewBox() throws {
        let svg = try parseAndRender("packet\n0-15: \"test\"")
        XCTAssertTrue(svg.contains("viewBox=\"0 0"))
    }

    func testSvgBlockRects() throws {
        let source = """
        packet
        title TCP
        0-15: "Source Port"
        16-31: "Destination Port"
        """
        let svg = try parseAndRender(source)
        // Should have 2 rects plus background rect
        let rectCount = svg.components(separatedBy: "<rect").count - 1
        XCTAssertEqual(rectCount, 3) // 2 blocks + background
    }

    func testEmptyPacketSvgDrawsPlaceholderFrame() throws {
        let svg = try parseAndRender("packet")

        let rectCount = svg.components(separatedBy: "<rect").count - 1
        XCTAssertEqual(rectCount, 2)
        XCTAssertTrue(svg.contains("class=\"packetBlock\""))
    }

    func testSvgLabels() throws {
        let svg = try parseAndRender("packet\n0-15: \"Source Port\"")
        XCTAssertTrue(svg.contains("class=\"packetLabel\""))
        XCTAssertTrue(svg.contains("Source Port"))
    }

    func testSvgBitNumbers() throws {
        let svg = try parseAndRender("packet\n0-15: \"test\"")
        XCTAssertTrue(svg.contains("class=\"packetByte start\""))
        XCTAssertTrue(svg.contains("class=\"packetByte end\""))
    }

    func testSvgBitNumbersHaveClearanceAboveBlocks() throws {
        let svg = try parseAndRender("packet\n0-15: \"test\"")
        let blockY = try firstDouble(in: svg, after: "<rect x=\"1.0\" y=\"")
        let bitY = try firstDouble(in: svg, after: "<text x=\"1.0\" y=\"")

        XCTAssertGreaterThanOrEqual(blockY - bitY, 5)
        XCTAssertGreaterThanOrEqual(bitY, 12)
    }

    func testSvgNoBitNumbers() throws {
        var diagram: PacketDiagram
        do {
            let lines = _mermaidSourceLines(from: "packet\n0-15: \"test\"")
            diagram = try parsePacketDiagram(lines, frontmatter: nil)
        }
        diagram.config.showBits = false
        let positioned = layoutPacketDiagram(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#000000")
        let svg = renderPacketSvg(positioned, colors, "Inter", false, theme: diagram.theme)
        // The CSS may contain "packetByte" but SVG elements with class="packetByte" should not appear
        // Check that no text elements have the packetByte class
        XCTAssertFalse(svg.contains("class=\"packetByte start\""))
        XCTAssertFalse(svg.contains("class=\"packetByte end\""))
    }

    func testSvgSingleBitLabel() throws {
        let svg = try parseAndRender("packet\n0-15: \"test\"\n16: \"single\"")
        // Single-bit: start label should be centered (text-anchor="middle") on the single-bit block
        // The second block (16: "single") is a single-bit field
        // No end label for single-bit since we check both blocks
        let startLabels = svg.components(separatedBy: "class=\"packetByte start\"")
        // We should have 2 start labels (one for the range block, one for the single-bit block)
        XCTAssertEqual(startLabels.count - 1, 2)
        // The single-bit block shouldn't have an end label with class "packetByte end" separately,
        // but the multi-bit block (0-15) does have an end label
        let endLabels = svg.components(separatedBy: "class=\"packetByte end\"")
        XCTAssertEqual(endLabels.count - 1, 1) // Only the 0-15 block has an end label
    }

    func testSvgMultiBitLabels() throws {
        let svg = try parseAndRender("packet\n0-15: \"test\"")
        XCTAssertTrue(svg.contains("text-anchor=\"start\""))
        XCTAssertTrue(svg.contains("text-anchor=\"end\""))
    }

    func testSvgTitle() throws {
        let source = """
        packet
        title TCP Packet
        0-15: "Source Port"
        """
        let svg = try parseAndRender(source)
        XCTAssertTrue(svg.contains("class=\"packetTitle\""))
        XCTAssertTrue(svg.contains("TCP Packet"))
    }

    func testSvgAccessibility() throws {
        let source = """
        packet
        accTitle: Test Title
        accDescr: Test Description
        0-15: "test"
        """
        let lines = _mermaidSourceLines(from: source)
        let diagram = try parsePacketDiagram(lines, frontmatter: nil)
        let positioned = layoutPacketDiagram(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#000000")
        let svg = renderPacketSvg(positioned, colors, "Inter", false, theme: diagram.theme)
        XCTAssertTrue(svg.contains("<title>Test Title</title>"))
        XCTAssertTrue(svg.contains("<desc>Test Description</desc>"))
    }

    func testSvgMaxWidth() throws {
        let svg = try parseAndRender("packet\n0-15: \"test\"")
        XCTAssertTrue(svg.contains("width=\"100%\""))
        XCTAssertTrue(svg.contains("max-width"))
    }

    func testSvgExplicitSize() throws {
        let lines = _mermaidSourceLines(from: "packet\n0-15: \"test\"")
        var diagram = try parsePacketDiagram(lines, frontmatter: nil)
        diagram.config.useMaxWidth = false
        let positioned = layoutPacketDiagram(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#000000")
        let svg = renderPacketSvg(positioned, colors, "Inter", false, theme: diagram.theme)
        // Should have explicit numeric width (not width="100%")
        XCTAssertTrue(svg.contains("width=\"1026"))
    }

    func testSvgThemeVariables() throws {
        let customTheme = PacketThemeConfig(
            byteFontSize: "8px",
            startByteColor: "red",
            endByteColor: "blue",
            labelColor: "green",
            labelFontSize: "14px",
            titleColor: "purple",
            titleFontSize: "16px",
            blockStrokeColor: "orange",
            blockStrokeWidth: "2",
            blockFillColor: "#cccccc"
        )
        let svg = try parseAndRender("packet\n0-15: \"test\"", theme: customTheme)
        XCTAssertTrue(svg.contains("font-size: 8px"))
        XCTAssertTrue(svg.contains("fill: red"))
        XCTAssertTrue(svg.contains("fill: blue"))
        XCTAssertTrue(svg.contains("fill: green"))
        XCTAssertTrue(svg.contains("font-size: 14px"))
        XCTAssertTrue(svg.contains("fill: purple"))
        XCTAssertTrue(svg.contains("font-size: 16px"))
        XCTAssertTrue(svg.contains("stroke: orange"))
        XCTAssertTrue(svg.contains("stroke-width: 2"))
        XCTAssertTrue(svg.contains("fill: #cccccc"))
    }

    func testSvgBitLabelBaselineAuto() throws {
        let svg = try parseAndRender("packet\n0-15: \"test\"\n16: \"single\"")
        let byteTextElements = svg.components(separatedBy: "class=\"packetByte")
        var autoCount = 0
        for fragment in byteTextElements.dropFirst() {
            if fragment.contains("dominant-baseline=\"auto\"") {
                autoCount += 1
            }
        }
        XCTAssertEqual(autoCount, 3) // 2 for range block (start + end), 1 for single-bit (start only)
    }
}
