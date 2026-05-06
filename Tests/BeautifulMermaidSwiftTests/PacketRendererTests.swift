import XCTest
@testable import BeautifulMermaid
import CoreGraphics

final class PacketRendererTests: XCTestCase {

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
        let diagram = try parsePacketDiagram(lines, frontmatter: nil)
        let positioned = layoutPacketDiagram(diagram)
        let graph = MermaidGraph(payload: .packet(diagram))
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
        let diagram = PacketDiagram.empty
        let positioned = layoutPacketDiagram(diagram)
        let graph = MermaidGraph(payload: .packet(diagram))
        let positionedGraph = PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .packet(positioned))

        let width = max(Int(positioned.width), 1)
        let height = max(Int(positioned.height), 1)
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

    func testPositionedGraphPacketAccessor() throws {
        let diagram = try parsePacketDiagram(_mermaidSourceLines(from: "packet\n0-15: \"test\""), frontmatter: nil)
        let positioned = layoutPacketDiagram(diagram)
        let graph = MermaidGraph(payload: .packet(diagram))
        let positionedGraph = PositionedGraph(
            diagram: graph,
            width: positioned.width,
            height: positioned.height,
            content: .packet(positioned)
        )

        XCTAssertEqual(positionedGraph.packetData?.rows.first?.first?.label, "test")
    }

    func testCoreGraphicsUsesPacketThemeBlockFillColor() throws {
        var diagram = try parsePacketDiagram(_mermaidSourceLines(from: "packet\n0-15: \"test\""), frontmatter: nil)
        diagram.theme = PacketThemeConfig(blockFillColor: "#ff0000")
        let positioned = layoutPacketDiagram(diagram)
        let graph = MermaidGraph(payload: .packet(diagram))
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
}
