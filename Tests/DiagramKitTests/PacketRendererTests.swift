import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG
import CoreGraphics

final class PacketRendererTests: XCTestCase {

    private func renderPacketPixels(_ diagram: PacketDiagram) throws -> (pixels: [UInt8], width: Int, height: Int, positioned: PositionedPacketDiagram) {
        let positioned = layoutPacketDiagram(diagram)
        let graph = DiagramDocument(payload: .packet(diagram))
        let positionedGraph = PositionedGraph(
            diagram: graph,
            width: positioned.width,
            height: positioned.height,
            content: .packet(positioned)
        )

        let width = max(Int(positioned.width), 1)
        let height = max(Int(positioned.height), 1)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Could not create CGContext")
            return (pixels, width, height, positioned)
        }

        DiagramRenderer().render(positionedGraph, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))
        return (pixels, width, height, positioned)
    }

    private func isRedPixel(_ pixels: [UInt8], at index: Int) -> Bool {
        pixels[index] > 180 && pixels[index + 1] < 90 && pixels[index + 2] < 90 && pixels[index + 3] > 180
    }

    private func isWhitePixel(_ pixels: [UInt8], at index: Int) -> Bool {
        pixels[index] > 248 && pixels[index + 1] > 248 && pixels[index + 2] > 248 && pixels[index + 3] > 248
    }

    func testCgRenderDoesNotCrash() throws {
        let source = """
        packet
        title TCP Packet
        0-15: "Source Port"
        16-31: "Destination Port"
        32-63: "Sequence Number"
        64-95: "Acknowledgment Number"
        96-99: "Data Offset"
        100-105: "Reserved"
        106: "URG"
        107: "ACK"
        108: "PSH"
        109: "RST"
        110: "SYN"
        111: "FIN"
        112-127: "Window"
        128-143: "Checksum"
        144-159: "Urgent Pointer"
        160-191: "(Options and Padding)"
        192-255: "Data (variable length)"
        """
        let lines = _mermaidSourceLines(from: source)
        let (diagram, _) = try parsePacketDiagram(lines, frontmatter: nil)
        let positioned = layoutPacketDiagram(diagram)
        let graph = DiagramDocument(payload: .packet(diagram))
        let positionedGraph = PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .packet(positioned))

        // Create a CGContext for rendering
        let width = Int(positioned.width)
        let height = Int(positioned.height)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Could not create CGContext")
            return
        }

        let renderer = DiagramRenderer()
        renderer.render(positionedGraph, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))
        // No crash = success
    }

    func testEmptyPacketRenders() throws {
        let rendered = try renderPacketPixels(.empty)

        var nonWhitePixelCount = 0
        for index in stride(from: 0, to: rendered.pixels.count, by: 4) {
            if !isWhitePixel(rendered.pixels, at: index) {
                nonWhitePixelCount += 1
            }
        }
        XCTAssertGreaterThan(nonWhitePixelCount, 100)
    }

    func testPositionedGraphPacketAccessor() throws {
        let (diagram, _) = try parsePacketDiagram(_mermaidSourceLines(from: "packet\n0-15: \"test\""), frontmatter: nil)
        let positioned = layoutPacketDiagram(diagram)
        let graph = DiagramDocument(payload: .packet(diagram))
        let positionedGraph = PositionedGraph(
            diagram: graph,
            width: positioned.width,
            height: positioned.height,
            content: .packet(positioned)
        )

        XCTAssertEqual(positionedGraph.packetData?.rows.first?.first?.label, "test")
    }

    func testCoreGraphicsUsesPacketThemeBlockFillColor() throws {
        var (diagram, _) = try parsePacketDiagram(_mermaidSourceLines(from: "packet\n0-15: \"test\""), frontmatter: nil)
        diagram.theme = PacketThemeConfig(blockFillColor: "#ff0000")
        let positioned = layoutPacketDiagram(diagram)
        let graph = DiagramDocument(payload: .packet(diagram))
        let positionedGraph = PositionedGraph(
            diagram: graph,
            width: positioned.width,
            height: positioned.height,
            content: .packet(positioned)
        )

        let width = Int(positioned.width)
        let height = Int(positioned.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Could not create CGContext")
            return
        }

        DiagramRenderer().render(positionedGraph, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))

        var redPixelCount = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            if pixels[index] > 240, pixels[index + 1] < 30, pixels[index + 2] < 30, pixels[index + 3] > 240 {
                redPixelCount += 1
            }
        }
        XCTAssertGreaterThan(redPixelCount, 100)
    }

    func testCoreGraphicsKeepsBitLabelsAbovePacketBlocks() throws {
        var (diagram, _) = try parsePacketDiagram(_mermaidSourceLines(from: "packet\n0-15: \"test\""), frontmatter: nil)
        diagram.theme = PacketThemeConfig(
            byteFontSize: "10px",
            startByteColor: "#ff0000",
            endByteColor: "#ff0000",
            blockStrokeColor: "#000000",
            blockFillColor: "#ffffff"
        )
        let rendered = try renderPacketPixels(diagram)
        let block = rendered.positioned.rows[0][0]
        let blockTopY = Int(block.y.rounded(.down))
        let blockBottomY = Int((block.y + block.height).rounded(.up))

        var redPixelCountInsideBlocks = 0
        for modelY in blockTopY..<blockBottomY {
            let pixelY = rendered.height - 1 - modelY
            let rowStart = pixelY * rendered.width * 4
            for index in stride(from: rowStart, to: rowStart + rendered.width * 4, by: 4) {
                if isRedPixel(rendered.pixels, at: index) {
                    redPixelCountInsideBlocks += 1
                }
            }
        }

        XCTAssertEqual(redPixelCountInsideBlocks, 0)
    }
}
