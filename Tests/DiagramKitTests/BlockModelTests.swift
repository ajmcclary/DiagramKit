import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

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

    func testBMColorAcceptsShortCSSHex() {
        let color = BMColor(hex: "#6cf")
        let expected = BMColor(red: 0x66 / 255.0, green: 0xcc / 255.0, blue: 0xff / 255.0, alpha: 1)
        XCTAssertTrue(color.bmColorEquals(expected))
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

    func testBlockArrowPointsAllDirectionCombinations() {
        let dirs: [[BlockDirection]] = [
            [.right], [.left], [.up], [.down],
            [.x], [.y],
            [.right, .left], [.up, .down],
            [.right, .up], [.right, .down],
            [.left, .up], [.left, .down],
            [.right, .left, .up], [.right, .left, .down],
            [.right, .up, .down], [.left, .up, .down],
            [.x, .y],
        ]
        for dirs in dirs {
            let points = getBlockArrowPoints(directions: dirs, width: 100, height: 60, padding: 8)
            XCTAssertGreaterThan(points.count, 1, "Direction combination \(dirs) produced insufficient points")
            if dirs.count >= 4 || dirs.contains(.x) && dirs.contains(.y) {
                XCTAssertGreaterThan(points.count, 6, "Four-direction arrow should have 8+ points")
            }
        }
    }

    func testWidthExceedsColumnsLogsWarning() throws {
        resetBlockWarnings()
        let source = """
        block-beta
          columns 1
          A:1
          B:2
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        _ = try? layoutBlockDiagram(diagram)
        let warnings = blockWarnings()
        let found = warnings.contains { $0.contains("B") && $0.contains("exceeds") }
        XCTAssertTrue(found, "Expected warning about block width exceeding columns, got: \(warnings)")
        resetBlockWarnings()
    }
}
