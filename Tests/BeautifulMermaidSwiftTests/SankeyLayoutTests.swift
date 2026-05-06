import XCTest
@testable import BeautifulMermaid

final class SankeyLayoutTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    func testLayoutEmptyDiagram() {
        let diagram = SankeyDiagram.empty
        let positioned = layoutSankeyDiagram(diagram)
        XCTAssertEqual(positioned.nodes.count, 0)
        XCTAssertEqual(positioned.links.count, 0)
    }

    func testLayoutSingleLink() throws {
        let diagram = try parseSankeyDiagram(lines("sankey\nA,B,10"))
        let positioned = layoutSankeyDiagram(diagram)
        XCTAssertEqual(positioned.nodes.count, 2)
        XCTAssertEqual(positioned.links.count, 1)
    }

    func testLayoutNodePositionsSet() throws {
        let diagram = try parseSankeyDiagram(lines("sankey\nA,B,10\nB,C,20"))
        let positioned = layoutSankeyDiagram(diagram)
        for node in positioned.nodes {
            XCTAssertGreaterThan(node.x1, node.x0, "Node width should be positive")
            XCTAssertGreaterThan(node.y1, node.y0, "Node height should be positive")
            XCTAssertGreaterThanOrEqual(node.layer, 0, "Layer should be non-negative")
        }
    }

    func testLayoutNodeWidthDefault() throws {
        let diagram = try parseSankeyDiagram(lines("sankey\nA,B,10"))
        let positioned = layoutSankeyDiagram(diagram)
        for node in positioned.nodes {
            XCTAssertEqual(node.x1 - node.x0, diagram.config.nodeWidth, accuracy: 0.01)
        }
    }

    func testLayoutNodeWidthCustom() throws {
        let config = SankeyDiagramConfig(nodeWidth: 20)
        let fm = DiagramFrontmatter(sankeyConfig: config)
        let diagram = try parseSankeyDiagram(lines("sankey\nA,B,10"), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)
        for node in positioned.nodes {
            XCTAssertEqual(node.x1 - node.x0, 20, accuracy: 0.01)
        }
    }

    func testLayoutShowValuesPadding() throws {
        let config1 = SankeyDiagramConfig(showValues: false)
        let fm1 = DiagramFrontmatter(sankeyConfig: config1)
        let diagram1 = try parseSankeyDiagram(lines("sankey\nA,B,10\nA,C,20"), frontmatter: fm1)
        let pos1 = layoutSankeyDiagram(diagram1)

        let config2 = SankeyDiagramConfig(showValues: true)
        let fm2 = DiagramFrontmatter(sankeyConfig: config2)
        let diagram2 = try parseSankeyDiagram(lines("sankey\nA,B,10\nA,C,20"), frontmatter: fm2)
        let pos2 = layoutSankeyDiagram(diagram2)

        let n1 = pos1.nodes.first(where: { $0.id == "A" })!
        let n2 = pos2.nodes.first(where: { $0.id == "A" })!
        XCTAssertNotEqual(n1.y0, n2.y0, "Y positions should differ due to showValues padding")
    }

    func testLayoutDimensionsFromConfig() throws {
        let config = SankeyDiagramConfig(width: 800, height: 600)
        let fm = DiagramFrontmatter(sankeyConfig: config)
        let diagram = try parseSankeyDiagram(lines("sankey\nA,B,10"), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)
        XCTAssertEqual(positioned.width, 800)
        XCTAssertEqual(positioned.height, 600)
    }

    func testLayoutLinksHavePaths() throws {
        let diagram = try parseSankeyDiagram(lines("sankey\nA,B,10\nB,C,20"))
        let positioned = layoutSankeyDiagram(diagram)
        XCTAssertEqual(positioned.links.count, 2)
        for link in positioned.links {
            XCTAssertGreaterThan(link.width, 0, "Link width should be positive")
        }
    }

    func testLayoutLinkWidthProportionalToValue() throws {
        let diagram = try parseSankeyDiagram(lines("sankey\nA,B,10\nA,C,100"))
        let positioned = layoutSankeyDiagram(diagram)
        let smallLink = positioned.links.first(where: { $0.value < 50 })!
        let largeLink = positioned.links.first(where: { $0.value > 50 })!
        XCTAssertGreaterThan(largeLink.width, smallLink.width, "Larger value link should have greater width")
    }

    func testDuplicateSameValueLinksReceiveDistinctOffsets() throws {
        let diagram = try parseSankeyDiagram(lines("sankey\nA,B,10\nA,B,10"))
        let positioned = layoutSankeyDiagram(diagram)
        XCTAssertEqual(positioned.links.count, 2)
        XCTAssertNotEqual(positioned.links[0].path.sourceY, positioned.links[1].path.sourceY)
        XCTAssertNotEqual(positioned.links[0].path.targetY, positioned.links[1].path.targetY)
    }

    func testNaNAndInfiniteValuesDoNotPoisonLayout() throws {
        let diagram = try parseSankeyDiagram(lines("sankey\nA,B,abc\nB,C,Infinity"))
        let positioned = layoutSankeyDiagram(diagram)
        for node in positioned.nodes {
            XCTAssertTrue(node.x0.isFinite)
            XCTAssertTrue(node.x1.isFinite)
            XCTAssertTrue(node.y0.isFinite)
            XCTAssertTrue(node.y1.isFinite)
            XCTAssertTrue(node.value.isFinite)
        }
        for link in positioned.links {
            XCTAssertTrue(link.width.isFinite)
            XCTAssertTrue(link.path.sourceY.isFinite)
            XCTAssertTrue(link.path.targetY.isFinite)
        }
    }

    func testLayoutWithLeftAlignment() throws {
        let config = SankeyDiagramConfig(nodeAlignment: .left)
        let fm = DiagramFrontmatter(sankeyConfig: config)
        let diagram = try parseSankeyDiagram(lines("sankey\nA,B,10\nB,C,20"), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)
        XCTAssertEqual(positioned.nodes.count, 3)
    }

    func testLayoutWithRightAlignment() throws {
        let config = SankeyDiagramConfig(nodeAlignment: .right)
        let fm = DiagramFrontmatter(sankeyConfig: config)
        let diagram = try parseSankeyDiagram(lines("sankey\nA,B,10\nB,C,20"), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)
        XCTAssertEqual(positioned.nodes.count, 3)
    }

    func testLayoutWithCenterAlignment() throws {
        let config = SankeyDiagramConfig(nodeAlignment: .center)
        let fm = DiagramFrontmatter(sankeyConfig: config)
        let diagram = try parseSankeyDiagram(lines("sankey\nA,B,10\nB,C,20"), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)
        XCTAssertEqual(positioned.nodes.count, 3)
    }

    func testLayoutWithJustifyAlignment() throws {
        let config = SankeyDiagramConfig(nodeAlignment: .justify)
        let fm = DiagramFrontmatter(sankeyConfig: config)
        let diagram = try parseSankeyDiagram(lines("sankey\nA,B,10\nB,C,20"), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)
        XCTAssertEqual(positioned.nodes.count, 3)
    }

    func testLayoutSingleNode() throws {
        let diagram = SankeyDiagram(
            nodes: [SankeyNode(id: "solo", rawID: "solo")],
            links: []
        )
        let positioned = layoutSankeyDiagram(diagram)
        XCTAssertEqual(positioned.nodes.count, 1)
    }

    func testLayoutDisconnectedNodes() throws {
        let diagram = try parseSankeyDiagram(lines("sankey\nA,B,10\nC,D,20"))
        let positioned = layoutSankeyDiagram(diagram)
        XCTAssertEqual(positioned.nodes.count, 4)
        XCTAssertEqual(positioned.links.count, 2)
    }
}
