import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

final class PacketLayoutTests: XCTestCase {

    private func parse(_ source: String) throws -> PacketDiagram {
        let lines = _mermaidSourceLines(from: source)
        return try parsePacketDiagram(lines, frontmatter: nil)
    }

    func testSingleBlockLayout() throws {
        let diagram = try parse("packet\n0-15: \"test\"")
        let positioned = layoutPacketDiagram(diagram)

        XCTAssertEqual(positioned.rows.count, 1)
        let block = positioned.rows[0][0]
        // width = (15-0+1)*32 - 5 = 507
        XCTAssertEqual(block.width, 507, accuracy: 0.01)
        // x = 0*32 + 1 = 1
        XCTAssertEqual(block.x, 1, accuracy: 0.01)
        // effectivePaddingY with showBits=true: 5 + 16 = 21
        XCTAssertEqual(block.y, 21, accuracy: 0.01)
    }

    func testDiagramDimensions() throws {
        let diagram = try parse("packet\n0-15: \"test\"")
        // Set a title to test title-inclusive height
        var titled = diagram
        titled.diagramTitle = "Test"
        let positioned = layoutPacketDiagram(titled)

        // width = 32*32 + 2 = 1026
        XCTAssertEqual(positioned.width, 1026, accuracy: 0.01)
        // height with title = (32+21)*(1+1) - 0 = 106
        XCTAssertEqual(positioned.height, 106, accuracy: 0.01)
    }

    func testShowBitsPaddingY() throws {
        var diagram = try parse("packet\n0-15: \"test\"")
        diagram.config.showBits = true
        let positioned = layoutPacketDiagram(diagram)

        // effectivePaddingY = 5 + 16 = 21
        let block = positioned.rows[0][0]
        XCTAssertEqual(block.y, 21, accuracy: 0.01)
    }

    func testNoShowBitsPaddingY() throws {
        var diagram = try parse("packet\n0-15: \"test\"")
        diagram.config.showBits = false
        let positioned = layoutPacketDiagram(diagram)

        // effectivePaddingY = 5
        let block = positioned.rows[0][0]
        XCTAssertEqual(block.y, 5, accuracy: 0.01)
    }

    func testMultiRowLayout() throws {
        let source = """
        packet
        0-10: "test"
        11-90: "multiple"
        """
        let diagram = try parse(source)
        let positioned = layoutPacketDiagram(diagram)

        XCTAssertEqual(positioned.rows.count, 3)
        // Row 0 y and Row 1 y differ by rowHeight + effectivePaddingY
        let row0Y = positioned.rows[0][0].y
        let row1Y = positioned.rows[1][0].y
        let effectivePaddingY = packetEffectivePaddingY(diagram.config)
        let rowHeightTotal = diagram.config.rowHeight + effectivePaddingY
        XCTAssertEqual(row1Y - row0Y, rowHeightTotal, accuracy: 0.01)
    }

    func testNoTitleHeightAdjustment() throws {
        let diagram = try parse("packet\n0-15: \"test\"")
        // No title
        let positioned = layoutPacketDiagram(diagram)

        // height without title = (32+21)*(1+1) - 32 = 74
        XCTAssertEqual(positioned.height, 74, accuracy: 0.01)
    }

    func testEmptyPacketReservesVisibleRowBounds() throws {
        let positioned = layoutPacketDiagram(.empty)

        XCTAssertTrue(positioned.rows.isEmpty)
        XCTAssertEqual(positioned.width, 1026, accuracy: 0.01)
        XCTAssertEqual(positioned.height, 74, accuracy: 0.01)
    }

    func testCustomConfig() throws {
        var diagram = try parse("packet\n0-15: \"test\"")
        diagram.config.rowHeight = 40
        diagram.config.bitWidth = 20
        diagram.config.bitsPerRow = 16
        let positioned = layoutPacketDiagram(diagram)

        // width = 20*16 + 2 = 322
        XCTAssertEqual(positioned.width, 322, accuracy: 0.01)
        // block width = (15-0+1)*20 - 5 = 315
        let block = positioned.rows[0][0]
        XCTAssertEqual(block.width, 315, accuracy: 0.01)
        XCTAssertEqual(block.height, 40, accuracy: 0.01)
    }
}
