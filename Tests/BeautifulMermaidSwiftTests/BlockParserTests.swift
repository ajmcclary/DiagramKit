import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class BlockParserTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private func parse(_ source: String) throws -> BlockDiagram {
        let (processed, _) = _parseFrontMatterAndStripped(source)
        let lns = _mermaidSourceLines(from: processed, separatedBy: CharacterSet(charactersIn: "\n"))
        return try parseBlockDiagramLines(lns)
    }

    func testBlockHeader() throws {
        let diagram = try parse("block\n  a")
        XCTAssertNotNil(diagram.blockDatabase["a"])
        XCTAssertEqual(diagram.blockDatabase["a"]?.label, "a")
    }

    func testBlockBetaHeader() throws {
        let diagram = try parse("block-beta\n  a")
        XCTAssertNotNil(diagram.blockDatabase["a"])
    }

    func testLeadingWhitespaceHeader() throws {
        let diagram = try parse("  block\n  a")
        XCTAssertNotNil(diagram.blockDatabase["a"])
    }

    func testBareNodeDefaultsLabelToId() throws {
        let diagram = try parse("block\n  a")
        let node = diagram.blockDatabase["a"]
        XCTAssertEqual(node?.label, "a")
        XCTAssertEqual(node?.type, .square)
    }

    func testMultipleBareNodes() throws {
        let diagram = try parse("block\n  a b c")
        XCTAssertNotNil(diagram.blockDatabase["a"])
        XCTAssertNotNil(diagram.blockDatabase["b"])
        XCTAssertNotNil(diagram.blockDatabase["c"])
        XCTAssertEqual(diagram.rootChildren.count, 3)
    }

    func testColumns() throws {
        let diagram = try parse("block\n  columns 3\n  a")
        let root = diagram.blockDatabase["root"]
        XCTAssertEqual(root?.columns, 3)
    }

    func testColumnsAuto() throws {
        let diagram = try parse("block\n  columns auto\n  a")
        let root = diagram.blockDatabase["root"]
        XCTAssertEqual(root?.columns, -1)
    }

    func testSquareShape() throws {
        let diagram = try parse("block\n  A[\"Square Label\"]")
        let node = diagram.blockDatabase["A"]
        XCTAssertEqual(node?.type, .square)
        XCTAssertEqual(node?.label, "Square Label")
    }

    func testRoundShape() throws {
        let diagram = try parse("block\n  A(\"Rounded\")")
        let node = diagram.blockDatabase["A"]
        XCTAssertEqual(node?.type, .round)
        XCTAssertEqual(node?.label, "Rounded")
    }

    func testCircleShape() throws {
        let diagram = try parse("block\n  A((\"Circle\"))")
        let node = diagram.blockDatabase["A"]
        XCTAssertEqual(node?.type, .circle)
    }

    func testDoubleCircleShape() throws {
        let diagram = try parse("block\n  A(((\"Double Circle\")))")
        let node = diagram.blockDatabase["A"]
        XCTAssertEqual(node?.type, .doublecircle)
    }

    func testStadiumShape() throws {
        let diagram = try parse("block\n  A([\"Stadium\"])")
        let node = diagram.blockDatabase["A"]
        XCTAssertEqual(node?.type, .stadium)
    }

    func testSubroutineShape() throws {
        let diagram = try parse("block\n  A[[\"Subroutine\"]]")
        let node = diagram.blockDatabase["A"]
        XCTAssertEqual(node?.type, .subroutine)
    }

    func testCylinderShape() throws {
        let diagram = try parse("block\n  A[(\"Database\")]")
        let node = diagram.blockDatabase["A"]
        XCTAssertEqual(node?.type, .cylinder)
    }

    func testDiamondShape() throws {
        let diagram = try parse("block\n  A{\"Diamond\"}")
        let node = diagram.blockDatabase["A"]
        XCTAssertEqual(node?.type, .diamond)
    }

    func testHexagonShape() throws {
        let diagram = try parse("block\n  A{{\"Hexagon\"}}")
        let node = diagram.blockDatabase["A"]
        XCTAssertEqual(node?.type, .hexagon)
    }

    func testColumnSpan() throws {
        let diagram = try parse("block\n  columns 3\n  A:2")
        let node = diagram.blockDatabase["A"]
        XCTAssertEqual(node?.widthInColumns, 2)
    }

    func testSpaceBlock() throws {
        let diagram = try parse("block\n  columns 3\n  a space b")
        let spaceNodes = diagram.blockDatabase.filter { $0.value.type == .space }
        XCTAssertFalse(spaceNodes.isEmpty)
    }

    func testSpaceBlockWithSpan() throws {
        let diagram = try parse("block\n  columns 3\n  a space:2 b")
        let spaceNodes = diagram.blockDatabase.filter { $0.value.type == .space }
        XCTAssertFalse(spaceNodes.isEmpty)
    }

    func testSimpleEdge() throws {
        let diagram = try parse("block\n  A B\n  A --> B")
        XCTAssertFalse(diagram.edges.isEmpty)
        XCTAssertEqual(diagram.edges.first?.start, "A")
        XCTAssertEqual(diagram.edges.first?.end, "B")
        XCTAssertEqual(diagram.edges.first?.arrowTypeEnd, "arrow_point")
    }

    func testEdgeStatementsDoNotOverwriteExistingNodes() throws {
        let diagram = try parse("""
        block
          A["Alpha"] B("Beta")
          A --> B
        """)

        XCTAssertEqual(diagram.blockDatabase["A"]?.label, "Alpha")
        XCTAssertEqual(diagram.blockDatabase["A"]?.type, .square)
        XCTAssertEqual(diagram.blockDatabase["B"]?.label, "Beta")
        XCTAssertEqual(diagram.blockDatabase["B"]?.type, .round)
        XCTAssertEqual(diagram.rootChildren, ["A", "B"])
    }

    func testEdgeChainsDoNotOverwriteCompositeBlocks() throws {
        let diagram = try parse("""
        block
          block:frontend["Frontend"]
            WebApp
          end
          block:backend["Backend"]
            API
          end
          frontend --> backend
        """)

        XCTAssertEqual(diagram.blockDatabase["frontend"]?.type, .composite)
        XCTAssertEqual(diagram.blockDatabase["frontend"]?.label, "Frontend")
        XCTAssertEqual(diagram.blockDatabase["frontend"]?.children, ["WebApp"])
        XCTAssertEqual(diagram.blockDatabase["backend"]?.type, .composite)
        XCTAssertEqual(diagram.rootChildren, ["frontend", "backend"])
    }

    func testBidirectionalEdge() throws {
        let diagram = try parse("block\n  A B\n  A <--> B")
        let edge = diagram.edges.first
        XCTAssertEqual(edge?.start, "A")
        XCTAssertEqual(edge?.end, "B")
    }

    func testThickEdge() throws {
        let diagram = try parse("block\n  A B\n  A ==> B")
        let edge = diagram.edges.first
        XCTAssertEqual(edge?.thickness, "thick")
    }

    func testDottedEdge() throws {
        let diagram = try parse("block\n  A B\n  A -.-> B")
        let edge = diagram.edges.first
        XCTAssertEqual(edge?.pattern, "dotted")
    }

    func testBlockArrow() throws {
        let diagram = try parse("block\n  A arrow<[\"Arrow\"]>(right) B")
        let arrowNodes = diagram.blockDatabase.filter { $0.value.type == .blockArrow }
        XCTAssertFalse(arrowNodes.isEmpty)
        let arrow = arrowNodes.first?.value
        XCTAssertEqual(arrow?.label, "Arrow")
    }

    func testBlockArrowWithXDirections() throws {
        let diagram = try parse("block\n  A arrow<[\"Arrow\"]>(x) B")
        let arrow = diagram.blockDatabase.first(where: { $0.value.type == .blockArrow })?.value
        XCTAssertNotNil(arrow)
        let dirs = arrow?.directions ?? []
        XCTAssertTrue(dirs.contains(.x))
    }

    func testCompositeBlock() throws {
        let source = """
        block
          block:group["Group"]
            columns 2
            x y
          end
        """
        let diagram = try parse(source)
        let group = diagram.blockDatabase["group"]
        XCTAssertNotNil(group)
        XCTAssertEqual(group?.type, .composite)
    }

    func testNestedCompositeBlock() throws {
        let source = """
        block
          block:outer["Outer"]
            block:inner["Inner"]
              a
            end
          end
        """
        let diagram = try parse(source)
        let outer = diagram.blockDatabase["outer"]
        let inner = diagram.blockDatabase["inner"]
        XCTAssertNotNil(outer)
        XCTAssertNotNil(inner)
    }

    func testMissingCompositeEndThrows() {
        let source = """
        block
          block:group["Group"]
            a
        """
        XCTAssertThrowsError(try parse(source))
    }

    func testStyleStatement() throws {
        let source = """
        block
          A
          style A fill:#ff0000,stroke:#000000
        """
        let diagram = try parse(source)
        let a = diagram.blockDatabase["A"]
        XCTAssertNotNil(a)
    }

    func testClassDefStatement() throws {
        let source = """
        block
          classDef blue fill:#6e6ce6,stroke:#333
          A
        """
        let diagram = try parse(source)
        XCTAssertNotNil(diagram.classes["blue"])
        XCTAssertEqual(diagram.classes["blue"]?.styles.first, "fill:#6e6ce6")
    }

    func testClassStatement() throws {
        let source = """
        block
          classDef blue fill:#6cf
          A
          class A blue
        """
        let diagram = try parse(source)
        XCTAssertNotNil(diagram.blockDatabase["A"])
        XCTAssertEqual(diagram.blockDatabase["A"]?.classes, ["blue"])
    }

    func testParseThroughMermaidParser() throws {
        let graph = try MermaidParser.parse("block\n  a b c")
        guard case .block = graph.payload else {
            XCTFail("Expected block payload, got \(graph.payload)")
            return
        }
    }

    func testBlockDetectionBeforeFlowchart() throws {
        let graph = try MermaidParser.parse("block\n  a b c")
        XCTAssertEqual(graph.type, .block)
    }
}
