import XCTest
@testable import BeautifulMermaid

final class BlockModelTests: XCTestCase {

    func testEmptyBlockDiagram() {
        let diagram = BlockDiagram.empty
        XCTAssertEqual(diagram.rootId, "root")
        XCTAssertNotNil(diagram.blockDatabase["root"])
        XCTAssertEqual(diagram.blockDatabase["root"]?.type, .composite)
    }

    func testLabelDefaultsToId() throws {
        let diagram = try MermaidParser.parse("block\n  a")
        guard case .block(let bd) = diagram.payload else { XCTFail(); return }
        let node = bd.blockDatabase["a"]
        XCTAssertEqual(node?.label, "a")
    }

    func testBlockNodeTypeEnum() {
        XCTAssertEqual(BlockNodeType.square.rawValue, "square")
        XCTAssertEqual(BlockNodeType.round.rawValue, "round")
        XCTAssertEqual(BlockNodeType.composite.rawValue, "composite")
        XCTAssertEqual(BlockNodeType.blockArrow.rawValue, "block_arrow")
    }

    func testBlockDiagramConfigDefaults() {
        let config = BlockDiagramConfig.default
        XCTAssertEqual(config.padding, 8)
        XCTAssertEqual(config.useMaxWidth, true)
    }

    func testBlockBounds() {
        let bounds = BlockBounds(x: 1, y: 2, width: 100, height: 200)
        XCTAssertEqual(bounds.x, 1)
        XCTAssertEqual(bounds.y, 2)
        XCTAssertEqual(bounds.width, 100)
        XCTAssertEqual(bounds.height, 200)
    }

    func testEdgeTypeStrToThickness() {
        XCTAssertEqual(edgeTypeStrToThickness("==>"), "thick")
        XCTAssertEqual(edgeTypeStrToThickness("-->"), "normal")
    }

    func testEdgeStrToPattern() {
        XCTAssertEqual(edgeStrToPattern("-.-"), "dotted")
        XCTAssertEqual(edgeStrToPattern("---"), "solid")
    }

    func testEdgeStrToEdgeData() {
        XCTAssertEqual(edgeStrToEdgeData("-->"), "arrow_point")
        XCTAssertEqual(edgeStrToEdgeData("--o"), "arrow_circle")
        XCTAssertEqual(edgeStrToEdgeData("--x"), "arrow_cross")
        XCTAssertEqual(edgeStrToEdgeData("---"), "")
    }

    func testPositionedBlockDiagramEmpty() {
        let pd = PositionedBlockDiagram.empty
        XCTAssertTrue(pd.blocks.isEmpty)
        XCTAssertTrue(pd.edges.isEmpty)
    }
}
