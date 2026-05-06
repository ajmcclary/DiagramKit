import XCTest
import CoreGraphics
@testable import BeautifulMermaid

final class BlockRendererTests: XCTestCase {

    func testRendererDispatchesBlock() throws {
        let source = """
        block
          a b c
        """
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)
        guard case .block = positioned.content else {
            XCTFail("Expected block content")
            return
        }
    }

    func testSimpleBlockDispatches() throws {
        let source = """
        block
          A["Hello"] B["World"]
        """
        let graph = try MermaidParser.parse(source)
        XCTAssertEqual(graph.type, .block)
    }

    func testBlockNoLongerFallsThroughToFlowchart() throws {
        let graph = try MermaidParser.parse("block\n  a")
        XCTAssertEqual(graph.type, .block)
        XCTAssertNotEqual(graph.type, .flowchart)
    }

    func testAsciiBlockReturnsNotYetImplemented() {
        XCTAssertThrowsError(try original_src_ascii_index.renderMermaidASCII("block\n  a")) { error in
            guard case BeautifulMermaidError.notYetImplemented = error else {
                XCTFail("Expected notYetImplemented error")
                return
            }
        }
    }

    func testDiagramTypeAllCasesContainsBlock() {
        XCTAssertTrue(DiagramType.allCases.contains(.block))
    }

    func testFrontmatterBlockConfig() {
        let source = """
        ---
        config.block.padding: 12
        ---
        block
          a
        """
        let (_, fm) = _parseFrontMatterAndStripped(source)
        XCTAssertEqual(fm?.blockConfig?.padding, 12)
    }

    func testCoreGraphicsDiamondDoesNotRenderAsBoundingRectangle() {
        let node = PositionedBlockNode(
            id: "D",
            label: "",
            type: .diamond,
            x: 100,
            y: 100,
            width: 80,
            height: 80,
            styles: ["fill:#ff0000", "stroke:#ff0000"]
        )
        let diagram = PositionedBlockDiagram(
            blocks: [node],
            edges: [],
            width: 200,
            height: 200,
            bounds: BlockBounds(x: 0, y: 0, width: 200, height: 200)
        )
        let graph = MermaidGraph(payload: .block(.empty))
        let positioned = PositionedGraph(
            diagram: graph,
            width: 200,
            height: 200,
            content: .block(diagram)
        )

        let width = 200
        let height = 200
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let context else {
            XCTFail("Expected bitmap context")
            return
        }

        DiagramRenderer(theme: DiagramTheme(background: BMColor.white, foreground: BMColor.black)).render(
            positioned,
            in: context,
            bounds: CGRect(x: 0, y: 0, width: width, height: height)
        )

        let corner = pixel(in: pixels, width: width, x: 64, y: 64)
        let center = pixel(in: pixels, width: width, x: 100, y: 100)
        XCTAssertGreaterThan(corner.green, 220, "Diamond corner should remain background, not filled like a rectangle")
        XCTAssertGreaterThan(corner.blue, 220, "Diamond corner should remain background, not filled like a rectangle")
        XCTAssertGreaterThan(center.red, 180, "Diamond center should be filled")
        XCTAssertLessThan(center.green, 80, "Diamond center should be filled")
    }

    private func pixel(in pixels: [UInt8], width: Int, x: Int, y: Int) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let index = ((y * width) + x) * 4
        return (pixels[index], pixels[index + 1], pixels[index + 2], pixels[index + 3])
    }
}
