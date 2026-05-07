import Testing
@testable import BeautifulMermaid

@Suite("Treemap SVG")
struct TreemapSvgTests {

    @Test("SVG renders basic treemap structure")
    func basicSvg() throws {
        let diagram = makeDiagram()
        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "test-id", colors, "Inter", false)

        #expect(svg.hasPrefix("<svg"))
        #expect(svg.contains("</svg>"))
        #expect(svg.contains("treemapContainer"))
        #expect(svg.contains("treemapSection"))
        #expect(svg.contains("treemapLeaf"))
        #expect(svg.contains("treemapLabel"))
    }

    @Test("SVG includes title when present")
    func svgWithTitle() {
        var diagram = makeDiagram()
        diagram.diagramTitle = "Test Title"
        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "test-id", colors, "Inter", false)

        #expect(svg.contains("treemapTitle"))
        #expect(svg.contains("Test Title"))
    }

    @Test("SVG hides root section - root section not rendered")
    func svgHidesRootSection() {
        let diagram = makeDiagram()
        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "test-id", colors, "Inter", false)

        #expect(svg.contains("treemapSectionHeader"))
        #expect(svg.contains("treemapContainer"))
    }

    @Test("SVG renders clip paths with correct IDs")
    func svgClipPathsCorrect() {
        let diagram = makeDiagram()
        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "test-id", colors, "Inter", false)

        #expect(svg.contains("clipPath"))
        #expect(svg.contains("clip-section-"))
    }

    @Test("SVG escapes XML entities")
    func svgEscapesXml() {
        var diagram = makeDiagram()
        diagram.diagramTitle = "A & B"
        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "test-id", colors, "Inter", false)

        #expect(!svg.contains("& "))
        #expect(svg.contains("&amp;"))
    }

    @Test("SVG includes accessibility elements and useMaxWidth sizing")
    func svgAccessibilityAndSizing() {
        var diagram = makeDiagram()
        diagram.accTitle = "Accessible <Treemap>"
        diagram.accDescr = "Description & details"
        diagram.config.useMaxWidth = true
        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "test-id", colors, "Inter", false)

        #expect(svg.contains("<title>Accessible &lt;Treemap&gt;</title>"))
        #expect(svg.contains("<desc>Description &amp; details</desc>"))
        #expect(svg.contains("width=\"100%\""))
        #expect(svg.contains("max-width:"))
    }

    @Test("SVG applies classDef styles to rectangles and text")
    func svgAppliesClassDefStyles() throws {
        let diagram = try parseTreemapDiagram("""
        treemap
        classDef hot fill:#ff0000,stroke:#333,color:#111;
        "Category":::hot
            "Item": 10:::hot
        """)
        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "test-id", colors, "Inter", false)

        #expect(svg.contains("fill:#ff0000"))
        #expect(svg.contains("stroke:#333"))
        #expect(svg.contains("fill:#111"))
    }

    private func makeDiagram() -> TreemapDiagram {
        TreemapDiagram(
            nodes: [
                TreemapNode(name: "Category", children: [
                    TreemapNode(name: "Item 1", value: 10),
                    TreemapNode(name: "Item 2", value: 20)
                ])
            ]
        )
    }
}

private func parseTreemapDiagram(_ source: String) throws -> TreemapDiagram {
    let normalized = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    let rawLines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    return try parseTreemapDiagram(rawLines, frontmatter: nil)
}
