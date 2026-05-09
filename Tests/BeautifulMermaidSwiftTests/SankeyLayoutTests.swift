import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

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

    func testJustifyAlignmentMatchesD3() throws {
        let source = """
        sankey
        a,b,8
        b,c,8
        c,d,8
        d,e,8
        x,c,4
        c,y,4
        """
        let config = SankeyDiagramConfig(width: 410, nodeAlignment: .justify, useMaxWidth: false)
        let fm = DiagramFrontmatter(sankeyConfig: config)
        let diagram = try parseSankeyDiagram(lines(source), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)

        guard let nodeX = positioned.nodes.first(where: { $0.id == "x" }),
              let nodeY = positioned.nodes.first(where: { $0.id == "y" }) else {
            XCTFail("Cross-link nodes x and y not found")
            return
        }
        XCTAssertEqual(nodeX.x0, 0, accuracy: 0.01, "Justify: node x should be at layer 0")
        XCTAssertEqual(nodeY.x0, 400, accuracy: 0.01, "Justify: node y should be at last layer")
    }

    func testLeftAlignmentMatchesD3() throws {
        let source = """
        sankey
        a,b,8
        b,c,8
        c,d,8
        d,e,8
        x,c,4
        c,y,4
        """
        let config = SankeyDiagramConfig(width: 410, nodeAlignment: .left, useMaxWidth: false)
        let fm = DiagramFrontmatter(sankeyConfig: config)
        let diagram = try parseSankeyDiagram(lines(source), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)

        guard let nodeX = positioned.nodes.first(where: { $0.id == "x" }),
              let nodeY = positioned.nodes.first(where: { $0.id == "y" }) else {
            XCTFail("Cross-link nodes x and y not found")
            return
        }
        XCTAssertEqual(nodeX.x0, 0, accuracy: 0.01, "Left: node x should be at layer 0")
        XCTAssertEqual(nodeY.x0, 300, accuracy: 0.01, "Left: node y should be at layer 3")
    }

    func testRightAlignmentMatchesD3() throws {
        let source = """
        sankey
        a,b,8
        b,c,8
        c,d,8
        d,e,8
        x,c,4
        c,y,4
        """
        let config = SankeyDiagramConfig(width: 410, nodeAlignment: .right, useMaxWidth: false)
        let fm = DiagramFrontmatter(sankeyConfig: config)
        let diagram = try parseSankeyDiagram(lines(source), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)

        guard let nodeX = positioned.nodes.first(where: { $0.id == "x" }),
              let nodeY = positioned.nodes.first(where: { $0.id == "y" }) else {
            XCTFail("Cross-link nodes x and y not found")
            return
        }
        XCTAssertEqual(nodeX.x0, 100, accuracy: 0.01, "Right: node x should be at layer 1")
        XCTAssertEqual(nodeY.x0, 400, accuracy: 0.01, "Right: node y should be at last layer")
    }

    func testCenterAlignmentMatchesD3() throws {
        let source = """
        sankey
        a,b,8
        b,c,8
        c,d,8
        d,e,8
        x,c,4
        c,y,4
        """
        let config = SankeyDiagramConfig(width: 410, nodeAlignment: .center, useMaxWidth: false)
        let fm = DiagramFrontmatter(sankeyConfig: config)
        let diagram = try parseSankeyDiagram(lines(source), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)

        guard let nodeX = positioned.nodes.first(where: { $0.id == "x" }),
              let nodeY = positioned.nodes.first(where: { $0.id == "y" }) else {
            XCTFail("Cross-link nodes x and y not found")
            return
        }
        XCTAssertEqual(nodeX.x0, 100, accuracy: 0.01, "Center: node x should be at layer 1")
        XCTAssertEqual(nodeY.x0, 300, accuracy: 0.01, "Center: node y should be at layer 3")
    }

    func testFiveLayerChainHasCorrectXSpacing() throws {
        let source = """
        sankey
        a,b,1
        b,c,1
        c,d,1
        d,e,1
        """
        let config = SankeyDiagramConfig(width: 410, nodeAlignment: .left)
        let fm = DiagramFrontmatter(sankeyConfig: config)
        let diagram = try parseSankeyDiagram(lines(source), frontmatter: fm)
        let positioned = layoutSankeyDiagram(diagram)

        let sortedNodes = positioned.nodes.sorted(by: { $0.x0 < $1.x0 })
        XCTAssertEqual(sortedNodes.count, 5)
        XCTAssertEqual(sortedNodes[0].x0, 0, accuracy: 0.01)
        XCTAssertEqual(sortedNodes[4].x0, 400, accuracy: 0.01)
    }

    func testEnergyFlowLayoutDeterministic() throws {
        let source = """
        sankey
        Electricity grid,Over generation / exports,104.453
        Electricity grid,Heating and cooling - homes,113.726
        Electricity grid,H2 conversion,27.14
        Electricity grid,Industry,342.165
        Electricity grid,Losses,56.691
        """
        let diagram = try parseSankeyDiagram(lines(source))
        let positioned = layoutSankeyDiagram(diagram)
        XCTAssertEqual(positioned.nodes.count, 6)
        XCTAssertEqual(positioned.links.count, 5)
        for node in positioned.nodes {
            XCTAssertTrue(node.x0.isFinite && node.x0 >= 0)
            XCTAssertTrue(node.y0.isFinite && node.y0 >= 0)
            XCTAssertGreaterThan(node.x1, node.x0)
            XCTAssertGreaterThan(node.y1, node.y0)
        }
    }

    func testFullEnergyFlowLayoutStaysInsideConfiguredBounds() throws {
        let source = """
        sankey
        Electricity grid,Over generation / exports,104.453
        Electricity grid,Heating and cooling - homes,113.726
        Electricity grid,H2 conversion,27.14
        Electricity grid,Industry,342.165
        Electricity grid,Losses,56.691
        Electricity grid,National navigation,10.186
        Electricity grid,Rail transport,7.863
        Electricity grid,Lighting & appliances - commercial,90.008
        Electricity grid,Lighting & appliances - homes,93.494
        Electricity grid,Other,82.233
        Electricity grid,Agriculture,3.64
        Over generation / exports,National navigation,104.453
        Heating and cooling - homes,District heating,79.329
        Heating and cooling - homes,Residential,34.397
        H2 conversion,Road transport,27.14
        Losses,National navigation,56.691
        Industry,Agriculture,342.165
        National navigation,Bio-conversion,180.193
        National navigation,Freight,127.365
        National navigation,Road transport,7.423
        Rail transport,Public lighting,7.863
        Lighting & appliances - commercial,Public lighting,90.008
        Lighting & appliances - homes,Residential,79.279
        Lighting & appliances - homes,Public lighting,14.215
        Other,Road transport,82.233
        """
        let diagram = try parseSankeyDiagram(lines(source))
        let positioned = layoutSankeyDiagram(diagram)

        for node in positioned.nodes {
            XCTAssertGreaterThanOrEqual(node.y0, 0, "\(node.id) starts above the canvas")
            XCTAssertLessThanOrEqual(node.y1, positioned.height, "\(node.id) extends below the canvas")
        }
        for link in positioned.links {
            XCTAssertGreaterThanOrEqual(link.path.sourceY - link.width / 2, 0, "\(link.sourceID)->\(link.targetID) starts above the canvas")
            XCTAssertLessThanOrEqual(link.path.sourceY + link.width / 2, positioned.height, "\(link.sourceID)->\(link.targetID) extends below the canvas")
            XCTAssertGreaterThanOrEqual(link.path.targetY - link.width / 2, 0, "\(link.sourceID)->\(link.targetID) targets above the canvas")
            XCTAssertLessThanOrEqual(link.path.targetY + link.width / 2, positioned.height, "\(link.sourceID)->\(link.targetID) targets below the canvas")
        }
    }
}
