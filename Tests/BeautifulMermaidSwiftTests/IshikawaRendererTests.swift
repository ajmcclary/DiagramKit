import Testing
@testable import BeautifulMermaid
import CoreGraphics

@Suite("Ishikawa Renderer")
struct IshikawaRendererTests {

    @Test("Renderer produces non-blank output")
    func nonBlankOutput() throws {
        let positioned = PositionedGraph(
            diagram: MermaidGraph(payload: .ishikawa(IshikawaDiagram(
                root: IshikawaNode(text: "Problem")
            ))),
            width: 600,
            height: 400,
            content: .ishikawa(layoutIshikawaDiagram(IshikawaDiagram(
                root: IshikawaNode(text: "Problem")
            )))
        )
        var pixels = [UInt8](repeating: 0, count: 320 * 240 * 4)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixels,
                width: 320,
                height: 240,
                bitsPerComponent: 8,
                bytesPerRow: 320 * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            Issue.record("Could not create CGContext.")
            return
        }

        let renderer = DiagramRenderer()
        renderer.render(positioned, in: context, bounds: CGRect(x: 0, y: 0, width: 320, height: 240))

        var drawnPixelCount = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = pixels[index]
            let green = pixels[index + 1]
            let blue = pixels[index + 2]
            let alpha = pixels[index + 3]
            if alpha > 0, red < 245 || green < 245 || blue < 245 {
                drawnPixelCount += 1
            }
        }
        #expect(drawnPixelCount > 20)
    }

    @Test("End-to-end parse+layout+SVG render simple diagram")
    func endToEndSimpleDiagram() throws {
        let source = "ishikawa-beta\nProblem\n    Cause A"
        let graph = try MermaidParser.parse(source)
        #expect(graph.type == .ishikawa)
        if case .ishikawa(let diagram) = graph.payload {
            #expect(diagram.root?.text == "Problem")
            #expect(diagram.root?.children.first?.text == "Cause A")
        }
    }

    @Test("End-to-end parse+layout for ishikawa header variant")
    func endToEndIshikawaHeader() throws {
        let source = "ishikawa\nProblem\nCause A\n  Subcause A1\nCause B"
        let graph = try MermaidParser.parse(source)
        #expect(graph.type == .ishikawa)
        if case .ishikawa(let diagram) = graph.payload {
            #expect(diagram.root?.children.count == 2)
        }
    }

    @Test("End-to-end parse+layout with leading comment")
    func endToEndWithLeadingComment() throws {
        let source = "%% comment\nishikawa-beta\nProblem\n    Cause A"
        let graph = try MermaidParser.parse(source)
        #expect(graph.type == .ishikawa)
    }

    @Test("End-to-end parse+layout root-only")
    func endToEndRootOnly() throws {
        let source = "ishikawa-beta\nProblem"
        let graph = try MermaidParser.parse(source)
        #expect(graph.type == .ishikawa)
        if case .ishikawa(let diagram) = graph.payload {
            #expect(diagram.root?.children.isEmpty == true)
        }
    }

    @Test("Layout dispatch handles ishikawa type")
    func layoutDispatch() throws {
        let graph = MermaidGraph(payload: .ishikawa(IshikawaDiagram(
            root: IshikawaNode(text: "Problem")
        )))
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)
        #expect(positioned.diagram.type == .ishikawa)
    }

    @Test("SVG render produces valid SVG for simple diagram")
    func svgRenderSimple() async throws {
        let source = "ishikawa-beta\nProblem\n    Cause A"
        let svg = try await renderMermaidSVG(source)
        #expect(svg.contains("<svg"))
        #expect(svg.contains("ishikawa"))
        #expect(svg.contains("</svg>"))
    }

    @Test("SVG render handles root-only")
    func svgRenderRootOnly() async throws {
        let source = "ishikawa-beta\nProblem"
        let svg = try await renderMermaidSVG(source)
        #expect(svg.contains("<svg"))
        #expect(svg.contains("ishikawa"))
        #expect(svg.contains("</svg>"))
    }

    @Test("Frontmatter config flows through parse → layout → render")
    func frontmatterConfigFlow() throws {
        let source = "---\nconfig:\n  ishikawa:\n    diagramPadding: 50\n---\nishikawa-beta\nProblem\n    Cause A"
        let graph = try MermaidParser.parse(source)
        #expect(graph.type == .ishikawa)
        if case .ishikawa(let diagram) = graph.payload {
            #expect(diagram.config.diagramPadding == 50)
        }
    }

    @Test("Frontmatter theme flows through parse")
    func frontmatterThemeFlow() throws {
        let source = "---\nconfig:\n  theme: dark\n---\nishikawa-beta\nProblem\n    Cause A"
        let graph = try MermaidParser.parse(source)
        if case .ishikawa(let diagram) = graph.payload {
            #expect(diagram.themeName == "dark")
        }
    }
}
