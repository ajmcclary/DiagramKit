import CoreGraphics
import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("Treemap Renderer")
struct TreemapRendererTests {

    @Test("Core Graphics renderer accepts classDef styled treemap output")
    func coreGraphicsRendersStyledTreemap() throws {
        let diagram = try parseTreemapDiagram("""
        treemap
        classDef hot fill:#ff0000,stroke:#333,color:#111;
        "Category":::hot
            "Item": 10:::hot
        """)
        let positionedTreemap = layoutTreemapDiagram(diagram)
        let graph = MermaidGraph(payload: .treemap(diagram))
        let positioned = PositionedGraph(
            diagram: graph,
            width: positionedTreemap.width,
            height: positionedTreemap.svgHeight,
            content: .treemap(positionedTreemap)
        )

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 120,
            height: 80,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        #expect(context != nil)
        if let context {
            DiagramRenderer().render(positioned, in: context, bounds: CGRect(x: 0, y: 0, width: 120, height: 80))
        }
    }
}

private func parseTreemapDiagram(_ source: String) throws -> TreemapDiagram {
    let normalized = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    let rawLines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    return try parseTreemapDiagram(rawLines, frontmatter: nil)
}
