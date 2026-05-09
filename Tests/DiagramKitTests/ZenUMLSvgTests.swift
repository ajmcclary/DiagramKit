import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("ZenUML SVG")
struct ZenUMLSvgTests {

    @Test("SVG renders groups and comments from positioned geometry")
    func rendersGroupsAndComments() throws {
        let graph = try MermaidParser.parse("zenuml\ngroup Backend { @EC2 svc @RDS db }\nClient->svc: request\n// important")
        guard case .zenuml(let diagram) = graph.payload else { return }

        let svg = renderZenUMLSvg(layoutZenUMLDiagram(diagram))

        #expect(svg.contains("class=\"group-outline\""))
        #expect(svg.contains("Backend"))
        #expect(svg.contains("class=\"comment-text\""))
        #expect(svg.contains("important"))
    }

    @Test("SVG useMaxWidth true emits responsive width")
    func useMaxWidthTrue() throws {
        let svg = try _renderMermaidSVG("""
        %%{init: {"sequence": {"useMaxWidth": true}}}%%
        zenuml
        A->B: async
        """)

        #expect(svg.contains("width=\"100%\""))
        #expect(svg.contains("max-width:"))
        #expect(svg.contains("preserveAspectRatio=\"xMinYMin meet\""))
    }

    @Test("SVG useMaxWidth false emits absolute dimensions")
    func useMaxWidthFalse() throws {
        let svg = try _renderMermaidSVG("""
        %%{init: {"sequence": {"useMaxWidth": false}}}%%
        zenuml
        A->B: async
        """)

        #expect(!svg.contains("width=\"100%\""))
        #expect(!svg.contains("max-width:"))
        #expect(svg.contains("height=\""))
    }
}
