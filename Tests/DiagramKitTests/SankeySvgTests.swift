import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class SankeySvgTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private func render(_ source: String) throws -> String {
        let (diagram, _) = try parseSankeyDiagram(lines(source))
        let positioned = layoutSankeyDiagram(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")
        return renderSankeySvg(positioned, colors)
    }

    private func positionedForSvgTests(
        config: SankeyDiagramConfig = .default
    ) -> PositionedSankeyDiagram {
        let nodes = [
            PositionedSankeyNode(id: "A", x0: 0, x1: 10, y0: 0, y1: 100, value: 5, layer: 0),
            PositionedSankeyNode(id: "B", x0: 100, x1: 110, y0: 0, y1: 100, value: 10, layer: 1),
            PositionedSankeyNode(id: "C", x0: 200, x1: 210, y0: 0, y1: 100, value: 8, layer: 2),
            PositionedSankeyNode(id: "D", x0: 300, x1: 310, y0: 0, y1: 100, value: 8, layer: 3),
        ]
        let path = SankeyLinkPath(
            sourceX: 210,
            sourceY: 50,
            targetX: 300,
            targetY: 50,
            controlPoints: [CGPoint(x: 255, y: 50), CGPoint(x: 255, y: 50)]
        )
        return PositionedSankeyDiagram(
            width: 400,
            height: 120,
            nodes: nodes,
            links: [
                PositionedSankeyLink(sourceID: "C", targetID: "D", value: 8, width: 8, y0: 46, y1: 54, path: path),
            ],
            config: config
        )
    }

    func testSvgContainsSvgTag() throws {
        let svg = try render("sankey\nA,B,10")
        XCTAssertTrue(svg.contains("<svg"), "SVG should contain <svg tag")
        XCTAssertTrue(svg.contains("</svg>"), "SVG should contain </svg> closing tag")
    }

    func testSvgContainsNodes() throws {
        let svg = try render("sankey\nA,B,10")
        XCTAssertTrue(svg.contains(#"class="nodes""#) || svg.contains("nodes"), "SVG should contain nodes group")
    }

    func testSvgContainsLinks() throws {
        let svg = try render("sankey\nA,B,10")
        XCTAssertTrue(svg.contains(#"class="links""#) || svg.contains("links"), "SVG should contain links group")
    }

    func testSvgContainsNodeRects() throws {
        let svg = try render("sankey\nA,B,10")
        XCTAssertTrue(svg.contains("<rect"), "SVG should contain rect elements for nodes")
    }

    func testSvgContainsNodeIds() throws {
        let svg = try render("sankey\nA,B,10")
        XCTAssertTrue(svg.contains("node-"), "SVG should contain node- ids")
    }

    func testSvgContainsGradientForDefault() throws {
        let svg = try render("sankey\nA,B,10\nC,D,20")
        XCTAssertTrue(svg.contains("linearGradient"), "SVG should contain linearGradient for default gradient link color")
    }

    func testSvgWithSourceLinkColor() throws {
        let config = SankeyDiagramConfig(linkColor: .source)
        let fm = DiagramFrontmatter.with { $0.perDiagram.sankey.config = config }
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10"), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")
        let svg = renderSankeySvg(positioned, colors)
        XCTAssertTrue(svg.contains("<path"), "SVG should contain path elements")
    }

    func testSvgWithTargetLinkColor() throws {
        let config = SankeyDiagramConfig(linkColor: .target)
        let fm = DiagramFrontmatter.with { $0.perDiagram.sankey.config = config }
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10"), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")
        let svg = renderSankeySvg(positioned, colors)
        XCTAssertTrue(svg.contains("<path"), "SVG should contain path elements")
    }

    func testSvgWithFixedLinkColor() throws {
        let config = SankeyDiagramConfig(linkColor: .fixed("#ff0000"))
        let fm = DiagramFrontmatter.with { $0.perDiagram.sankey.config = config }
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10"), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")
        let svg = renderSankeySvg(positioned, colors)
        XCTAssertTrue(svg.contains("#ff0000"), "SVG should contain the fixed link color")
    }

    func testSvgSourceLinkColorUsesDefaultEndpointColor() throws {
        let positioned = positionedForSvgTests(config: SankeyDiagramConfig(linkColor: .source))
        let svg = renderSankeySvg(positioned, DiagramColors(bg: "#FFFFFF", fg: "#27272A"))
        XCTAssertTrue(svg.contains(##"stroke="#e15759""##), "C is the third node and should use Tableau10 index 2")
    }

    func testSvgGradientLinkColorUsesDefaultEndpointColors() throws {
        let positioned = positionedForSvgTests(config: SankeyDiagramConfig(linkColor: .gradient))
        let svg = renderSankeySvg(positioned, DiagramColors(bg: "#FFFFFF", fg: "#27272A"))
        XCTAssertTrue(svg.contains(##"stop-color="#e15759""##), "Gradient should start with the source node color")
        XCTAssertTrue(svg.contains(##"stop-color="#76b7b2""##), "Gradient should end with the target node color")
    }

    func testSvgWithLabels() throws {
        let svg = try render("sankey\nElectricity grid,Over generation,104.453")
        XCTAssertTrue(svg.contains("node-labels"), "SVG should contain label elements")
    }

    func testSvgWithShowValues() throws {
        let config = SankeyDiagramConfig(showValues: true, prefix: "$", suffix: "k")
        let fm = DiagramFrontmatter.with { $0.perDiagram.sankey.config = config }
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10"), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")
        let svg = renderSankeySvg(positioned, colors)
        XCTAssertTrue(svg.contains("$10k"), "SVG should contain formatted value without trailing zeros")
    }

    func testSvgLegacyLabelStyle() throws {
        let svg = try render("sankey\nElectricity grid,Over generation,104.453")
        XCTAssertTrue(svg.contains("text-anchor"), "Legacy labels should use text-anchor")
    }

    func testSvgOutlinedLabelStyle() throws {
        let config = SankeyDiagramConfig(labelStyle: .outlined)
        let fm = DiagramFrontmatter.with { $0.perDiagram.sankey.config = config }
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10"), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")
        let svg = renderSankeySvg(positioned, colors)
        XCTAssertTrue(svg.contains("sankey-label-bg") || svg.contains("node-labels"), "Outlined labels should be present")
    }

    func testSvgOutlinedLabelPlacesNodesBeforeCentralLayerOnLeft() throws {
        let positioned = positionedForSvgTests(config: SankeyDiagramConfig(showValues: false, labelStyle: .outlined))
        let svg = renderSankeySvg(positioned, DiagramColors(bg: "#FFFFFF", fg: "#27272A"))
        XCTAssertTrue(
            svg.contains(#"class="sankey-label-bg" x="-6" y="50" dy="0.35em" text-anchor="end">A</text>"#),
            "Outlined labels before the central layer should be placed to the left of the node"
        )
        XCTAssertTrue(
            svg.contains(#"class="sankey-label-bg" x="116" y="50" dy="0.35em" text-anchor="start">B</text>"#),
            "Outlined labels at the central layer should be placed to the right of the node"
        )
    }

    func testSvgAccessibility() throws {
        let fm = DiagramFrontmatter.with { $0.shared.title = "Test Title" }
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10"), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")
        let svg = renderSankeySvg(positioned, colors)
        XCTAssertTrue(svg.contains("<title>"), "SVG should contain accessibility title")
        XCTAssertTrue(svg.contains(#"role="graphics-document document""#))
        XCTAssertTrue(svg.contains(#"aria-roledescription="sankey""#))
        XCTAssertTrue(svg.contains(#"aria-label="Test Title""#))
    }

    func testSvgUseMaxWidth() throws {
        let config = SankeyDiagramConfig(useMaxWidth: true)
        let fm = DiagramFrontmatter.with { $0.perDiagram.sankey.config = config }
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10"), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)
        let colors = DiagramColors(bg: "#FFFFFF", fg: "#27272A")
        let svg = renderSankeySvg(positioned, colors)
        XCTAssertTrue(svg.contains("viewBox=\"0 0"), "SVG viewBox should start at 0 0 when useMaxWidth is true")
    }

    func testMultiNodeDiagram() throws {
        let svg = try render("sankey\nA,B,10\nB,C,20\nC,D,30")
        XCTAssertTrue(svg.contains("<path"), "Multi-node diagram should have paths")
    }

    func testEnergyFlowRenders() throws {
        let source = """
        sankey
        Electricity grid,Over generation / exports,104.453
        Electricity grid,Heating and cooling - homes,113.726
        Electricity grid,H2 conversion,27.14
        Electricity grid,Industry,342.165
        Electricity grid,Losses,56.691
        """
        let svg = try render(source)
        XCTAssertFalse(svg.isEmpty)
        XCTAssertTrue(svg.contains("</svg>"))
    }

    func testLinkColorHexRendersAsStroke() throws {
        let config = SankeyDiagramConfig(linkColor: .fixed("#636465"))
        let positioned = positionedForSvgTests(config: config)
        let svg = renderSankeySvg(positioned, DiagramColors(bg: "#FFFFFF", fg: "#27272A"))
        XCTAssertTrue(svg.contains(##"stroke="#636465""##), "Link stroke should use fixed hex color")
    }

    func testLinkColorSourceUsesSourceNodeColor() throws {
        let positioned = positionedForSvgTests(config: SankeyDiagramConfig(linkColor: .source))
        let svg = renderSankeySvg(positioned, DiagramColors(bg: "#FFFFFF", fg: "#27272A"))
        XCTAssertTrue(svg.contains(##"stroke="#e15759""##), "Source link should use source node (C) color")
    }

    func testLinkColorTargetUsesTargetNodeColor() throws {
        let positioned = positionedForSvgTests(config: SankeyDiagramConfig(linkColor: .target))
        let svg = renderSankeySvg(positioned, DiagramColors(bg: "#FFFFFF", fg: "#27272A"))
        XCTAssertTrue(svg.contains(##"stroke="#76b7b2""##), "Target link should use target node (D) color")
    }

    func testLinkColorGradientUsesGradientRef() throws {
        let positioned = positionedForSvgTests(config: SankeyDiagramConfig(linkColor: .gradient))
        let svg = renderSankeySvg(positioned, DiagramColors(bg: "#FFFFFF", fg: "#27272A"))
        XCTAssertTrue(svg.contains("url(#linearGradient-"), "Gradient link should reference a gradient id")
    }

    func testLegacyLabelDoesNotHaveOutlinedClasses() throws {
        let config = SankeyDiagramConfig(labelStyle: .legacy)
        let positioned = positionedForSvgTests(config: config)
        let svg = renderSankeySvg(positioned, DiagramColors(bg: "#FFFFFF", fg: "#27272A"))
        XCTAssertFalse(svg.contains(#"class="sankey-label-bg""#), "Legacy labels should not use outlined bg class on elements")
        XCTAssertFalse(svg.contains(#"class="sankey-label-fg""#), "Legacy labels should not use outlined fg class on elements")
        XCTAssertTrue(svg.contains("node-labels"), "Legacy labels should still have node-labels group")
    }

    func testOutlinedLabelHasBothClasses() throws {
        let config = SankeyDiagramConfig(labelStyle: .outlined)
        let positioned = positionedForSvgTests(config: config)
        let svg = renderSankeySvg(positioned, DiagramColors(bg: "#FFFFFF", fg: "#27272A"))
        XCTAssertTrue(svg.contains("sankey-label-bg"), "Outlined labels should have bg class")
        XCTAssertTrue(svg.contains("sankey-label-fg"), "Outlined labels should have fg class")
    }

    func testNodeRectWidthEqualsNodeWidthConfig() throws {
        let config = SankeyDiagramConfig(useMaxWidth: false, nodeWidth: 20)
        let fm = DiagramFrontmatter.with { $0.perDiagram.sankey.config = config }
        let (diagram, _) = try parseSankeyDiagram(lines("sankey\nA,B,10"), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)
        let svg = renderSankeySvg(positioned, DiagramColors(bg: "#FFFFFF", fg: "#27272A"))
        XCTAssertTrue(svg.contains(##"width="20""##), "Node rect should respect custom nodeWidth")
    }

    func testNodeRectDefaultWidthIs10() throws {
        let positioned = positionedForSvgTests()
        let svg = renderSankeySvg(positioned, DiagramColors(bg: "#FFFFFF", fg: "#27272A"))
        XCTAssertTrue(svg.contains(##"width="10""##), "Node rect should use default width of 10")
    }

    func testCustomNodeColorsOverrideFill() throws {
        let config = SankeyDiagramConfig(nodeColors: ["C": "#ff0000"])
        let positioned = positionedForSvgTests(config: config)
        let svg = renderSankeySvg(positioned, DiagramColors(bg: "#FFFFFF", fg: "#27272A"))
        XCTAssertTrue(svg.contains(##"fill="#ff0000""##), "Custom node color should override default")
    }

    func testShowValuesFormattingUsesRounding() throws {
        let config = SankeyDiagramConfig(showValues: true, prefix: "$", suffix: "k")
        let positioned = positionedForSvgTests(config: config)
        let svg = renderSankeySvg(positioned, DiagramColors(bg: "#FFFFFF", fg: "#27272A"))
        XCTAssertTrue(svg.contains("$5"), "Value 5 should format without trailing zeros")
    }
}
