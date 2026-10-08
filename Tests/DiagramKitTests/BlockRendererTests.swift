// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import XCTest
import CoreGraphics
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class BlockRendererTests: XCTestCase {

    func testRendererDispatchesBlock() throws {
        let source = """
        block
          a b c
        """
        let graph = try DiagramPipeline.parse(source)
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
        let graph = try DiagramPipeline.parse(source)
        XCTAssertEqual(graph.type, .block)
    }

    func testBlockNoLongerFallsThroughToFlowchart() throws {
        let graph = try DiagramPipeline.parse("block\n  a")
        XCTAssertEqual(graph.type, .block)
        XCTAssertNotEqual(graph.type, .flowchart)
    }

    func testAsciiBlockRendersBlockDiagram() throws {
        let rendered = try original_src_ascii_index.renderMermaidASCII("block\n  a")
        XCTAssertEqual(rendered, "[a]")
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
        XCTAssertEqual(fm?.perDiagram.block.config?.padding, 12)
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
        let graph = DiagramDocument(payload: .block(.empty))
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
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
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

    func testCoreGraphicsBlockRendererAccountsForDiagramBoundsOrigin() throws {
        let source = """
        block
          A B C
          classDef red fill:#ff0000,stroke:#ff0000
          class A red
        """
        let graph = try DiagramPipeline.parse(source)
        let positioned = try GraphLayout().layout(graph)
        guard case .block(let diagram) = positioned.content else {
            XCTFail("Expected block content")
            return
        }
        XCTAssertLessThan(diagram.bounds.x, 0)

        let width = Int(ceil(positioned.width))
        let height = Int(ceil(positioned.height))
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

        let redPixelCount = stride(from: 0, to: pixels.count, by: 4).filter { index in
            pixels[index] > 180 && pixels[index + 1] < 80 && pixels[index + 2] < 80
        }.count
        XCTAssertGreaterThan(redPixelCount, 50, "The leftmost styled block should be visible, not clipped off canvas")
    }

    func testCoreGraphicsCompositeBlockRendersChildren() throws {
        let source = """
        block
          block:group["Group"]
            A
          end
          classDef red fill:#ff0000,stroke:#ff0000
          class A red
        """
        let graph = try DiagramPipeline.parse(source)
        let positioned = try GraphLayout().layout(graph)

        let width = Int(ceil(positioned.width))
        let height = Int(ceil(positioned.height))
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

        let redPixelCount = stride(from: 0, to: pixels.count, by: 4).filter { index in
            pixels[index] > 180 && pixels[index + 1] < 80 && pixels[index + 2] < 80
        }.count
        XCTAssertGreaterThan(redPixelCount, 50, "Composite block children should be rendered in the CG path")
    }

    func testCoreGraphicsCompositeLabelDoesNotTouchCanvasTopEdge() throws {
        let source = """
        block
          block:group["Group"]
            columns 2
            x y
          end
        """

        let rendered = try renderBlockPixels(source)
        let topRowStart = (rendered.height - 1) * rendered.width * 4
        let topRowEnd = topRowStart + rendered.width * 4
        let topRowNonWhitePixelCount = stride(from: topRowStart, to: topRowEnd, by: 4).filter { index in
            rendered.pixels[index] < 250 || rendered.pixels[index + 1] < 250 || rendered.pixels[index + 2] < 250
        }.count

        XCTAssertEqual(topRowNonWhitePixelCount, 0, "Composite labels should not be clipped against the top image edge")
    }

    private func renderBlockPixels(_ source: String) throws -> (pixels: [UInt8], width: Int, height: Int) {
        let graph = try DiagramPipeline.parse(source)
        let positioned = try GraphLayout().layout(graph)
        let width = Int(ceil(positioned.width))
        let height = Int(ceil(positioned.height))
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
            return (pixels, width, height)
        }
        context.setFillColor(BMColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        DiagramRenderer(theme: DiagramTheme(background: BMColor.white, foreground: BMColor.black)).render(
            positioned,
            in: context,
            bounds: CGRect(x: 0, y: 0, width: width, height: height)
        )
        return (pixels, width, height)
    }

    private func pixel(in pixels: [UInt8], width: Int, x: Int, y: Int) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let index = ((y * width) + x) * 4
        return (pixels[index], pixels[index + 1], pixels[index + 2], pixels[index + 3])
    }
}
#endif
