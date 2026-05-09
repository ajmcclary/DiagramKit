import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG
import CoreGraphics

final class WardleyMapRendererTests: XCTestCase {
    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n").map(String.init)
    }

    func testCoreGraphicsDrawsAcceleratorAndDeacceleratorShapes() throws {
        let source = """
        wardley-beta
        accelerator "Cloud Migration" [0.3, 0.7]
        deaccelerator "Legacy Contracts" [0.7, 0.3]
        """
        var diagram = try parseWardleyMap(lines(source))
        diagram.theme = WardleyThemeVariables(
            componentFill: "#ff0000",
            componentStroke: "#ff0000",
            componentLabelColor: "#ff0000"
        )
        let positioned = layoutWardleyMap(diagram)
        let graph = MermaidGraph(payload: .wardleyBeta(diagram))
        let positionedGraph = PositionedGraph(
            diagram: graph,
            width: positioned.width,
            height: positioned.height,
            content: .wardleyBeta(positioned)
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
            if pixels[index] > 220, pixels[index + 1] < 40, pixels[index + 2] < 40, pixels[index + 3] > 220 {
                redPixelCount += 1
            }
        }
        XCTAssertGreaterThan(redPixelCount, 500)
    }
}
