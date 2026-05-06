import XCTest
@testable import BeautifulMermaid

final class PacketParserTests: XCTestCase {

    private func parse(_ source: String) throws -> PacketDiagram {
        let lines = _mermaidSourceLines(from: source)
        return try parsePacketDiagram(lines, frontmatter: nil)
    }

    // MARK: - Header tests

    func testPacketHeader() throws {
        let diagram = try parse("packet")
        XCTAssertTrue(diagram.rows.isEmpty)
    }

    func testPacketBetaHeader() throws {
        let diagram = try parse("packet-beta")
        XCTAssertTrue(diagram.rows.isEmpty)
    }

    func testLeadingWhitespaceHeader() throws {
        let diagram = try parse("  packet\n0-10: \"test\"")
        XCTAssertEqual(diagram.rows.count, 1)
    }

    func testTitleAndAccessibility() throws {
        let source = """
        packet
        title Packet diagram
        accTitle: Packet accTitle
        accDescr: Packet accDescription
        0-10: "test"
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.diagramTitle, "Packet diagram")
        XCTAssertEqual(diagram.accTitle, "Packet accTitle")
        XCTAssertEqual(diagram.accDescr, "Packet accDescription")
        XCTAssertEqual(diagram.rows.count, 1)
    }

    // MARK: - Block parsing tests

    func testExplicitRange() throws {
        let diagram = try parse("packet\n0-10: \"test\"")
        XCTAssertEqual(diagram.rows.count, 1)
        let block = diagram.rows[0][0]
        XCTAssertEqual(block.start, 0)
        XCTAssertEqual(block.end, 10)
        XCTAssertEqual(block.bits, 11)
        XCTAssertEqual(block.label, "test")
    }

    func testSingleBit() throws {
        let diagram = try parse("packet\n0-10: \"test\"\n11: \"single\"")
        XCTAssertEqual(diagram.rows.count, 1)
        let block = diagram.rows[0][1]
        XCTAssertEqual(block.start, 11)
        XCTAssertEqual(block.end, 11)
        XCTAssertEqual(block.bits, 1)
        XCTAssertEqual(block.label, "single")
    }

    func testBitCount() throws {
        let diagram = try parse("packet\n+8: \"byte\"\n+16: \"word\"")
        XCTAssertEqual(diagram.rows.count, 1)
        let first = diagram.rows[0][0]
        XCTAssertEqual(first.start, 0)
        XCTAssertEqual(first.end, 7)
        XCTAssertEqual(first.bits, 8)
        let second = diagram.rows[0][1]
        XCTAssertEqual(second.start, 8)
        XCTAssertEqual(second.end, 23)
        XCTAssertEqual(second.bits, 16)
    }

    func testMixedForms() throws {
        let diagram = try parse("packet\n0-10: \"range\"\n11: \"single\"\n+8: \"count\"")
        XCTAssertEqual(diagram.rows.count, 1)
        XCTAssertEqual(diagram.rows[0].count, 3)
        XCTAssertEqual(diagram.rows[0][0].bits, 11)
        XCTAssertEqual(diagram.rows[0][1].bits, 1)
        XCTAssertEqual(diagram.rows[0][2].bits, 8)
    }

    func testSingleQuotedLabel() throws {
        let diagram = try parse("packet\n0-7: 'byte'")
        XCTAssertEqual(diagram.rows[0][0].label, "byte")
    }

    func testEscapedQuotedLabel() throws {
        let diagram = try parse("packet\n0-7: \"quoted \\\"byte\\\"\"")
        XCTAssertEqual(diagram.rows[0][0].label, "quoted \"byte\"")
    }

    func testInlineBlockComment() throws {
        let diagram = try parse("packet\n0-7: \"byte\" %% comment")
        XCTAssertEqual(diagram.rows[0][0].label, "byte")
    }

    func testBlankLines() throws {
        let source = """
        packet

        0-10: "test"

        11-20: "test2"
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.rows[0].count, 2)
    }

    func testCommentLines() throws {
        let source = """
        packet
        %% comment
        0-10: "test"
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.rows[0][0].label, "test")
    }

    // MARK: - Row splitting tests

    func testRowSplitting() throws {
        // 0-10 spans 11 bit positions and 11-90 spans 80 positions.
        // With bitsPerRow=32, the second block splits across three rows.
        let source = """
        packet
        0-10: "test"
        11-90: "multiple"
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.rows.count, 3)
        XCTAssertEqual(diagram.rows[0].count, 2)
        XCTAssertEqual(diagram.rows[0][0].start, 0)
        XCTAssertEqual(diagram.rows[0][0].end, 10)
        XCTAssertEqual(diagram.rows[0][1].start, 11)
        XCTAssertEqual(diagram.rows[0][1].end, 31)
        XCTAssertEqual(diagram.rows[1][0].start, 32)
        XCTAssertEqual(diagram.rows[1][0].end, 63)
        XCTAssertEqual(diagram.rows[2][0].start, 64)
        XCTAssertEqual(diagram.rows[2][0].end, 90)
    }

    func testRowSplittingPreservesMermaidSplitBitsMetadata() throws {
        let source = """
        packet
        0-10: "test"
        11-90: "multiple"
        """
        let diagram = try parse(source)

        XCTAssertEqual(diagram.rows[0][1].bits, 20)
        XCTAssertEqual(diagram.rows[1][0].bits, 31)
        XCTAssertEqual(diagram.rows[2][0].bits, 26)
    }

    func testExactRowBoundary() throws {
        let source = """
        packet
        0-16: "test"
        17-63: "multiple"
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.rows.count, 2)
        XCTAssertEqual(diagram.rows[0][0].start, 0)
        XCTAssertEqual(diagram.rows[0][0].end, 16)
        XCTAssertEqual(diagram.rows[0][1].start, 17)
        XCTAssertEqual(diagram.rows[0][1].end, 31)
        XCTAssertEqual(diagram.rows[1][0].start, 32)
        XCTAssertEqual(diagram.rows[1][0].end, 63)
    }

    // MARK: - Validation error tests

    func testNotContiguous() throws {
        XCTAssertThrowsError(try parse("packet\n0-16: \"test\"\n18-20: \"error\"")) { error in
            guard let packetError = error as? PacketParserError else {
                XCTFail("Expected PacketParserError, got \(error)")
                return
            }
            if case .notContiguous = packetError {} else {
                XCTFail("Expected notContiguous, got \(packetError)")
            }
        }
    }

    func testNotContiguousBitCount() throws {
        XCTAssertThrowsError(try parse("packet\n+16: \"test\"\n18-20: \"error\""))
    }

    func testNotContiguousSingle() throws {
        XCTAssertThrowsError(try parse("packet\n0-16: \"test\"\n18: \"error\""))
    }

    func testEndBeforeStart() throws {
        XCTAssertThrowsError(try parse("packet\n0-16: \"test\"\n25-20: \"error\"")) { error in
            guard let packetError = error as? PacketParserError else { return }
            if case .invalidRange = packetError {} else {
                XCTFail("Expected invalidRange")
            }
        }
    }

    func testZeroBitField() throws {
        XCTAssertThrowsError(try parse("packet\n+0: \"test\"")) { error in
            guard let packetError = error as? PacketParserError else { return }
            if case .zeroBitField = packetError {} else {
                XCTFail("Expected zeroBitField")
            }
        }
    }

    func testMalformedHeader() throws {
        XCTAssertThrowsError(try parse("packetz\n0-10: \"test\""))
    }

    func testMissingLabel() throws {
        XCTAssertThrowsError(try parse("packet\n0-10:")) { error in
            guard let packetError = error as? PacketParserError else { return }
            if case .malformedBlock = packetError {} else {
                XCTFail("Expected malformedBlock")
            }
        }
    }

    func testTrailingTextAfterQuotedLabelThrows() throws {
        XCTAssertThrowsError(try parse("packet\n0-10: \"test\" trailing")) { error in
            guard let packetError = error as? PacketParserError else { return }
            if case .malformedBlock = packetError {} else {
                XCTFail("Expected malformedBlock")
            }
        }
    }

    func testUnterminatedQuotedLabelThrows() throws {
        XCTAssertThrowsError(try parse("packet\n0-10: \"test")) { error in
            guard let packetError = error as? PacketParserError else { return }
            if case .unterminatedString = packetError {} else {
                XCTFail("Expected unterminatedString")
            }
        }
    }

    func testUnquotedLabel() throws {
        XCTAssertThrowsError(try parse("packet\n0-10: test")) { error in
            guard let packetError = error as? PacketParserError else { return }
            if case .unquotedLabel = packetError {} else {
                XCTFail("Expected unquotedLabel")
            }
        }
    }

    // MARK: - MermaidParser integration test

    func testParseThroughMermaidParser() throws {
        let graph = try MermaidParser.parse("packet\n0-10: \"test\"")
        guard case .packet(let diagram) = graph.payload else {
            XCTFail("Expected packet payload")
            return
        }
        XCTAssertEqual(diagram.rows.count, 1)
        XCTAssertEqual(diagram.rows[0][0].label, "test")
    }

    func testFrontmatterPacketConfigAndTheme() throws {
        let source = """
        ---
        title: "Frontmatter Packet"
        config:
          packet:
            rowHeight: 40
            bitWidth: 20
            bitsPerRow: 16
            showBits: false
            paddingX: 10
            paddingY: 8
            useMaxWidth: false
        themeVariables:
          packet:
            startByteColor: red
            blockFillColor: "#cccccc"
        ---
        packet
        0-15: "test"
        """

        let preprocessed = _preprocessMermaidSource(source)
        let lines = _mermaidSourceLines(from: preprocessed.source)
        let diagram = try parsePacketDiagram(lines, frontmatter: preprocessed.frontmatter)

        XCTAssertEqual(diagram.diagramTitle, "Frontmatter Packet")
        XCTAssertEqual(diagram.config.rowHeight, 40)
        XCTAssertEqual(diagram.config.bitWidth, 20)
        XCTAssertEqual(diagram.config.bitsPerRow, 16)
        XCTAssertEqual(diagram.config.showBits, false)
        XCTAssertEqual(diagram.config.paddingX, 10)
        XCTAssertEqual(diagram.config.paddingY, 8)
        XCTAssertEqual(diagram.config.useMaxWidth, false)
        XCTAssertEqual(diagram.theme.startByteColor, "red")
        XCTAssertEqual(diagram.theme.blockFillColor, "#cccccc")
    }

    func testSourceTitleOverridesFrontmatterTitle() throws {
        let source = """
        ---
        title: "Frontmatter Packet"
        ---
        packet
        title Source Packet
        0-15: "test"
        """

        let preprocessed = _preprocessMermaidSource(source)
        let lines = _mermaidSourceLines(from: preprocessed.source)
        let diagram = try parsePacketDiagram(lines, frontmatter: preprocessed.frontmatter)

        XCTAssertEqual(diagram.diagramTitle, "Source Packet")
    }
}
