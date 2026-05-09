import CoreGraphics
import Testing
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

@Suite("ZenUML Core Graphics")
struct ZenUMLRendererTests {

    @Test("Renderer accepts positioned groups, comments, and open arrows")
    func rendersPositionedSurfaces() throws {
        let graph = try MermaidParser.parse("zenuml\ngroup Backend { @EC2 svc @RDS db }\nClient->svc: request\n// important")
        guard case .zenuml(let diagram) = graph.payload else {
            Issue.record("Expected ZenUML payload")
            return
        }
        let zenuml = layoutZenUMLDiagram(diagram)
        let positioned = PositionedGraph(
            diagram: graph,
            width: zenuml.width,
            height: zenuml.height,
            content: .zenuml(zenuml)
        )

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 640,
            height: 480,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            Issue.record("Expected bitmap context")
            return
        }

        DiagramRenderer().render(positioned, in: context, bounds: CGRect(x: 0, y: 0, width: 640, height: 480))
    }
}
