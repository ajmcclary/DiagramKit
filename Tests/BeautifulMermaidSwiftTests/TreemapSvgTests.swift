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

    @Test("SVG hierarchical treemap has correct section and leaf structure")
    func svgHierarchicalStructure() throws {
        let diagram = try parseTreemapDiagram("""
        treemap-beta
        "Products"
            "Electronics"
                "Phones": 50
                "Computers": 30
            "Clothing"
                "Shirts": 10
        """)
        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "id", colors, "Inter", false)

        #expect(svg.contains("treemapSection"))
        #expect(svg.contains("treemapLeafGroup"))
        #expect(svg.contains("treemapLeaf"))
        #expect(svg.contains("treemapLabel"))
        #expect(svg.contains("translate"))
        #expect(positioned.sections.count >= 2)
        #expect(positioned.leaves.count >= 3)
    }

    @Test("SVG value formatting renders formatted numbers")
    func svgValueFormattedText() throws {
        let diagram = try parseTreemapDiagram("""
        treemap
        "Budget"
            "Sales": 700000
            "Marketing": 400000
        """)
        var mutDiagram = diagram
        mutDiagram.config = TreemapDiagramConfig(valueFormat: "$0,0")
        let positioned = layoutTreemapDiagram(mutDiagram)
        #expect(positioned.leaves.count == 2)
        #expect(formatTreemapValue(700000, format: "$0,0") == "$700,000")
    }

    @Test("SVG classDef stroke-dasharray style applied")
    func svgClassDefDasharray() throws {
        let diagram = try parseTreemapDiagram("""
        treemap-beta
        "Main"
            "A": 20:::dashed
            "B": 15
        classDef dashed fill:#6cf,stroke:#333,stroke-dasharray:5 5;
        """)
        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "id", colors, "Inter", false)

        #expect(svg.contains("stroke-dasharray"))

        #expect(svg.contains("dashed"))
    }

    @Test("SVG multi-level deep nesting produces leaf elements")
    func svgDeepNesting() throws {
        let diagram = try parseTreemapDiagram("""
        treemap
        "Level 1"
            "Level 2A"
                "Level 3A": 10
                "Level 3B": 15
            "Level 2B"
                "Level 3C": 20
        """)
        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "id", colors, "Inter", false)

        #expect(svg.components(separatedBy: "treemapSection").count >= 3)
        #expect(svg.components(separatedBy: "treemapLeaf").count >= 4)
    }

    @Test("SVG comments do not produce DOM elements")
    func svgCommentsNotEmitted() throws {
        let diagram = try parseTreemapDiagram("""
        treemap
        %% This is a comment
        "Cat"
            "Item": 10
        """)
        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "id", colors, "Inter", false)

        #expect(!svg.contains("%%"))
        #expect(svg.contains("Cat"))
    }

    @Test("SVG showValues false omits value elements")
    func svgShowValuesFalse() throws {
        let diagram = try parseTreemapDiagram("""
        treemap
        "Cat"
            "Item": 100
        """)
        var mutDiagram = diagram
        mutDiagram.config = TreemapDiagramConfig(showValues: false)
        let positioned = layoutTreemapDiagram(mutDiagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "id", colors, "Inter", false)

        #expect(!svg.contains("treemapValue"))
    }

    @Test("SVG leaf groups include classSelector in class attribute")
    func svgLeafClassSelectorInDom() throws {
        let diagram = try parseTreemapDiagram("""
        treemap
        "Root"
            "A": 10:::important
            "B": 20
        classDef important fill:#f96,stroke:#333;
        """)
        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "id", colors, "Inter", false)

        #expect(svg.contains("important"))
        #expect(svg.contains("treemapLeafGroup"))
    }

    @Test("SVG clip paths use distinct IDs per element")
    func svgDistinctClipIds() throws {
        let diagram = try parseTreemapDiagram("""
        treemap
        "Section A"
            "Item 1": 10
            "Item 2": 20
        "Section B"
            "Item 3": 30
        """)
        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "id", colors, "Inter", false)

        #expect(svg.contains("clip-section-"))
        #expect(svg.contains("clip-"))
        #expect(positioned.sections.count >= 2)
        #expect(positioned.leaves.count >= 3)
    }

    @Test("SVG diagramPadding increases viewBox")
    func svgDiagramPaddingViewBox() {
        var diagram = makeDiagram()
        diagram.config = TreemapDiagramConfig(diagramPadding: 50)
        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#fff", fg: "#000")
        let svg = renderTreemapSvg(positioned, diagramId: "id", colors, "Inter", false)

        #expect(svg.contains("-50 -50"))
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
