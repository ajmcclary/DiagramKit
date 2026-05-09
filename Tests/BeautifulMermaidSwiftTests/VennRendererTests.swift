import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
import CoreGraphics

final class VennRendererTests: XCTestCase {

    func testCgRenderDoesNotCrashForTwoSetIntersection() throws {
        let diagram = VennDiagram(
            areas: [
                VennArea(sets: ["A"], size: 10),
                VennArea(sets: ["B"], size: 10),
                VennArea(sets: ["A", "B"], size: 2.5, label: "AB")
            ]
        )
        let positioned = layoutVennDiagram(diagram)
        let graph = MermaidGraph(payload: .venn(diagram))
        let positionedGraph = PositionedGraph(
            diagram: graph,
            width: positioned.width,
            height: positioned.height,
            content: .venn(positioned)
        )

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
    }

    func testSvgArcPathConvertsToBoundedCgPath() throws {
        let path = _makeVennCGPath(from: "M 100 100 A 50 50 0 0 1 200 100 A 50 50 0 0 1 100 100 Z")
        let box = try XCTUnwrap(path?.boundingBoxOfPath)

        XCTAssertEqual(box.minX, 100, accuracy: 0.001)
        XCTAssertEqual(box.maxX, 200, accuracy: 0.001)
        XCTAssertGreaterThan(box.height, 90)
    }
}
