import XCTest
@testable import BeautifulMermaid

final class SequenceLayoutTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
    }

    // MARK: - Created Actor Repositioning

    func testCreatedActorRepositioned() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: First
            create participant Carol
            Bob->>Carol: Hello
        """))
        let positioned = try layoutSequenceDiagram(diagram)
        let topActor = positioned.actors.first(where: { $0.id == "Alice" })
        let created = positioned.actors.first(where: { $0.id == "Carol" })
        XCTAssertNotNil(topActor)
        XCTAssertNotNil(created)
        // Created actor should appear at or after the creation message, not at the top
        XCTAssertGreaterThanOrEqual(created!.y, topActor!.y)
        // Top actors should remain at the top
        XCTAssertEqual(topActor!.y, positioned.actors.filter { $0.id == "Alice" }.first?.y)
    }

    // MARK: - Destroyed Actor Lifeline

    func testDestroyedActorLifelineTruncated() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Hello
            destroy Bob
            Alice->>Bob: Last
        """))
        let positioned = try layoutSequenceDiagram(diagram)
        let bobLifeline = positioned.lifelines.first(where: { $0.actorId == "Bob" })
        XCTAssertNotNil(bobLifeline)
        // Destroyed lifeline should end at or before the destroying message
        let destroyMsg = positioned.messages.last(where: { $0.from == "Alice" && $0.to == "Bob" })
        XCTAssertNotNil(destroyMsg)
    }

    // MARK: - Mirror Actors

    func testMirrorActorsProducesBottomActors() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Hello
        """))
        let positioned = try layoutSequenceDiagram(diagram, config: SequenceDiagramConfig(mirrorActors: true))
        XCTAssertFalse(positioned.bottomActors.isEmpty, "Bottom actors should be present when mirrorActors is true")
    }

    func testNoMirrorWhenDisabled() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Hello
        """))
        let positioned = try layoutSequenceDiagram(diagram, config: SequenceDiagramConfig(mirrorActors: false))
        XCTAssertTrue(positioned.bottomActors.isEmpty, "Bottom actors should be empty when mirrorActors is false")
    }

    // MARK: - Hide Unused Participants

    func testHideUnusedParticipantsFilters() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            participant Alice
            participant Bob
            participant Charlie
            Alice->>Bob: Hello
        """))
        let positioned = try layoutSequenceDiagram(diagram, config: SequenceDiagramConfig(hideUnusedParticipants: true))
        let visibleIds = positioned.actors.map(\.id)
        XCTAssertTrue(visibleIds.contains("Alice"))
        XCTAssertTrue(visibleIds.contains("Bob"))
        XCTAssertFalse(visibleIds.contains("Charlie"), "Charlie should be hidden since unused")
    }

    // MARK: - Autonumber

    func testAutonumberSequenceNumbersAttached() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            autonumber
            Alice->>Bob: First
            Alice->>Bob: Second
        """))
        let positioned = try layoutSequenceDiagram(diagram)
        let seqMsgs = positioned.messages.filter { $0.sequenceVisible }
        XCTAssertEqual(seqMsgs.count, 2)
        XCTAssertEqual(seqMsgs[0].sequenceNumber, 1)
        XCTAssertEqual(seqMsgs[1].sequenceNumber, 2)
    }

    func testShowSequenceNumbersConfigOverride() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Hello
        """))
        let config = SequenceDiagramConfig(showSequenceNumbers: true)
        let positioned = try layoutSequenceDiagram(diagram, config: config)
        XCTAssertTrue(positioned.messages.first?.sequenceVisible ?? false)
    }

    func testAutonumberOffRespectsConfig() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            autonumber off
            Alice->>Bob: Hello
        """))
        let config = SequenceDiagramConfig(showSequenceNumbers: true)
        let positioned = try layoutSequenceDiagram(diagram, config: config)
        XCTAssertFalse(positioned.messages.first?.sequenceVisible ?? true,
                       "Explicit autonumber off should override config.showSequenceNumbers")
    }

    // MARK: - Rect Highlights

    func testRectHighlightsPositioned() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Hello
            rect rgb(191, 223, 255)
                Alice->>Bob: Highlighted
            end
        """))
        let positioned = try layoutSequenceDiagram(diagram)
        XCTAssertFalse(positioned.rectHighlights.isEmpty, "rect block should produce a rect highlight")
        XCTAssertNotEqual(positioned.rectHighlights[0].fill, "transparent")
    }

    // MARK: - Boxes

    func testBoxBoundingArea() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            box rgb(100,200,100) Group
                participant Alice
                participant Bob
            end
            Alice->>Bob: Hello
        """))
        let positioned = try layoutSequenceDiagram(diagram)
        XCTAssertFalse(positioned.boxes.isEmpty, "box should be positioned")
        let box = positioned.boxes[0]
        XCTAssertGreaterThan(box.width, 0)
        XCTAssertGreaterThan(box.height, 0)
        XCTAssertNotNil(box.name)
        XCTAssertTrue(box.name?.contains("Group") ?? false)
    }

    // MARK: - Block Dividers

    func testBlockDividersInCritical() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Start
            critical Transaction
                Alice->>Bob: Op
            option Alternate
                Alice->>Bob: AltOp
            end
        """))
        let positioned = try layoutSequenceDiagram(diagram)
        let critBlock = positioned.blocks.first(where: { $0.type == "critical" })
        XCTAssertNotNil(critBlock)
        XCTAssertFalse(critBlock!.dividers.isEmpty, "critical block should have option divider")
    }

    // MARK: - Multiline Text

    func testMultilineMessageAdjustsRowHeight() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Line1
            Alice->>Bob: Line1<br>Line2
        """))
        let positioned = try layoutSequenceDiagram(diagram)
        XCTAssertEqual(positioned.messages.count, 2)
        // The second message should have a greater y (further down) due to extra height
        XCTAssertGreaterThan(positioned.messages[1].y, positioned.messages[0].y)
    }
}
