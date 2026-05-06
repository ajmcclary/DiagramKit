import XCTest
@testable import BeautifulMermaid

final class BlockLayoutTests: XCTestCase {

    func testCalculateBlockPositionAuto() {
        let (px, py) = calculateBlockPosition(columns: -1, position: 5)
        XCTAssertEqual(px, 5)
        XCTAssertEqual(py, 0)
    }

    func testCalculateBlockPositionSingleColumn() {
        let (px, py) = calculateBlockPosition(columns: 1, position: 3)
        XCTAssertEqual(px, 0)
        XCTAssertEqual(py, 3)
    }

    func testCalculateBlockPositionMultiColumn() {
        let (px, py) = calculateBlockPosition(columns: 3, position: 0)
        XCTAssertEqual(px, 0)
        XCTAssertEqual(py, 0)
    }

    func testCalculateBlockPositionMultiColumnPosition4() {
        let (px, py) = calculateBlockPosition(columns: 3, position: 4)
        XCTAssertEqual(px, 1)
        XCTAssertEqual(py, 1)
    }

    func testCalculateBlockPositionMultiColumnPosition5() {
        let (px, py) = calculateBlockPosition(columns: 3, position: 5)
        XCTAssertEqual(px, 2)
        XCTAssertEqual(py, 1)
    }

    func testLayoutProducesPositionedDiagram() throws {
        let source = """
        block
          columns 3
          a b c
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        let positioned = try layoutBlockDiagram(diagram)
        XCTAssertGreaterThan(positioned.blocks.count, 0)
        XCTAssertGreaterThan(positioned.width, 0)
        XCTAssertGreaterThan(positioned.height, 0)
    }

    func testLayoutWithNestedComposites() throws {
        let source = """
        block
          block:group["Group"]
            a b
          end
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        let positioned = try layoutBlockDiagram(diagram)
        XCTAssertGreaterThan(positioned.blocks.count, 0)
    }

    func testLayoutWithEdges() throws {
        let source = """
        block
          A B
          A --> B
        """
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lines = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        let diagram = try parseBlockDiagramLines(lines)
        let positioned = try layoutBlockDiagram(diagram)
        XCTAssertFalse(positioned.edges.isEmpty)
    }
}
