import XCTest
@testable import BeautifulMermaid

final class SequenceParserTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
    }

    // MARK: - Participant Parsing

    func testParticipantBasic() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            participant Alice
            actor Bob
            Alice->>Bob: Hello
        """))
        let actors = diagram.actors
        XCTAssertEqual(actors.count, 2)
        XCTAssertEqual(actors[0].id, "Alice")
        XCTAssertEqual(actors[0].type, .participant)
        XCTAssertEqual(actors[1].id, "Bob")
        XCTAssertEqual(actors[1].type, .actor)
    }

    func testParticipantWithAlias() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            participant A as Alice
            actor B as Bob
            A->>B: Hello
        """))
        let actors = diagram.actors
        XCTAssertEqual(actors.first(where: { $0.id == "A" })?.label, "Alice")
        XCTAssertEqual(actors.first(where: { $0.id == "B" })?.label, "Bob")
    }

    func testParticipantWithConfig() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            participant API@{ "type": "boundary" } as Public API
            participant DB@{ "type": "database", "alias": "User DB" }
        """))
        let api = diagram.actors.first(where: { $0.id == "API" })
        XCTAssertEqual(api?.label, "Public API")
        XCTAssertEqual(api?.type, .boundary)
        let db = diagram.actors.first(where: { $0.id == "DB" })
        XCTAssertEqual(db?.label, "User DB")
        XCTAssertEqual(db?.type, .database)
    }

    func testParticipantAliasPrecedence() throws {
        // External 'as' takes precedence over inline alias
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            participant Svc@{ "type": "control", "alias": "Auth" } as Auth Service
        """))
        let svc = diagram.actors.first(where: { $0.id == "Svc" })
        XCTAssertEqual(svc?.label, "Auth Service")
        XCTAssertEqual(svc?.type, .control)
    }

    // MARK: - Arrow Type Parsing

    func testArrowSolidFilled() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A->>B: solid filled
        """))
        XCTAssertEqual(diagram.messages.first?.arrowType, .solid)
    }

    func testArrowDottedFilled() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A-->>B: dotted filled
        """))
        XCTAssertEqual(diagram.messages.first?.arrowType, .dotted)
    }

    func testArrowSolidOpen() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A->B: no arrowhead
        """))
        let style = SequenceArrowStyle(type: diagram.messages.first!.arrowType)
        XCTAssertFalse(style.hasArrowEnd)
    }

    func testArrowDottedOpen() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A-->B: no arrowhead dotted
        """))
        let style = SequenceArrowStyle(type: diagram.messages.first!.arrowType)
        XCTAssertFalse(style.hasArrowEnd)
        XCTAssertTrue(style.isDotted)
    }

    func testArrowCross() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A-xB: cross
            A--xB: dotted cross
        """))
        XCTAssertEqual(diagram.messages[0].arrowType, .solidCross)
        XCTAssertEqual(diagram.messages[1].arrowType, .dottedCross)
    }

    func testArrowAsync() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A-)B: async
            A--)B: dotted async
        """))
        XCTAssertEqual(diagram.messages[0].arrowType, .solidPoint)
        XCTAssertEqual(diagram.messages[1].arrowType, .dottedPoint)
    }

    func testArrowBidirectional() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A<<->>B: bidirectional
            A<<-->>B: bidirectional dotted
        """))
        XCTAssertEqual(diagram.messages[0].arrowType, .bidirectionalSolid)
        XCTAssertEqual(diagram.messages[1].arrowType, .bidirectionalDotted)
    }

    func testArrowHalfArrowTop() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A-|\\B: half top
        """))
        let style = SequenceArrowStyle(type: diagram.messages.first!.arrowType)
        XCTAssertTrue(style.isHalfArrow)
        XCTAssertEqual(style.halfArrowDirection, .top)
        XCTAssertEqual(style.halfArrowStyle, .arrow)
    }

    func testArrowStickBottom() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A-//B: stick bottom
        """))
        let style = SequenceArrowStyle(type: diagram.messages.first!.arrowType)
        XCTAssertTrue(style.isHalfArrow)
        XCTAssertEqual(style.halfArrowDirection, .bottom)
        XCTAssertEqual(style.halfArrowStyle, .stick)
    }

    func testArrowReverseHalfTop() throws {
        // /\|-  — reverse half arrow top
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A/\\|-B: reverse half top
        """))
        let style = SequenceArrowStyle(type: diagram.messages.first!.arrowType)
        XCTAssertTrue(style.isHalfArrow)
        XCTAssertTrue(style.isReversed)
        XCTAssertEqual(style.halfArrowDirection, .top)
        XCTAssertEqual(style.halfArrowStyle, .arrow)
    }

    func testArrowReverseStickBottom() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A\\\\-B: reverse stick bottom
        """))
        let style = SequenceArrowStyle(type: diagram.messages.first!.arrowType)
        XCTAssertTrue(style.isHalfArrow)
        XCTAssertTrue(style.isReversed)
        XCTAssertEqual(style.halfArrowDirection, .bottom)
        XCTAssertEqual(style.halfArrowStyle, .stick)
    }

    func testReverseMarkersInSVG() throws {
        // Verify SVG output contains reverse marker definitions
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A/\\|-B: rev arrow
            A\\\\-B: rev stick
        """))
        let layout = try layoutSequenceDiagram(diagram)
        let svg = try renderSequenceSvg(layout, DiagramColors(bg: "#FFFFFF", fg: "#333333"))
        XCTAssertTrue(svg.contains("seq-arrow-half-top-rev"), "SVG must contain reverse half marker")
        XCTAssertTrue(svg.contains("seq-arrow-stick-bottom-rev"), "SVG must contain reverse stick marker")
    }

    // MARK: - Central Connection

    func testCentralConnectionDest() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>()John: Hello
        """))
        XCTAssertEqual(diagram.messages.first?.centralConnection, .dest)
    }

    func testCentralConnectionSource() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice()->>John: How are you
        """))
        XCTAssertEqual(diagram.messages.first?.centralConnection, .source)
    }

    func testCentralConnectionBoth() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice()->>()John: Great
        """))
        XCTAssertEqual(diagram.messages.first?.centralConnection, .both)
    }

    // MARK: - Lifecycle: create / destroy

    func testCreateParticipant() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Hello
            create participant Charlie
            Bob->>Charlie: Hi Charlie
        """))
        XCTAssertTrue(diagram.createdActorIds.contains("Charlie"))
        XCTAssertEqual(diagram.messages.count, 2)
    }

    func testDestroyParticipant() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Hello
            destroy Bob
            Alice-xBob: Bye
        """))
        XCTAssertTrue(diagram.destroyedActorIds.contains("Bob"))
    }

    // MARK: - Activation

    func testDedicatedActivateDeactivate() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>John: Hello
            activate John
            John->>Alice: Hi
            deactivate John
        """))
        let activationStarts = diagram.items.filter { if case .activationStart = $0 { true } else { false } }
        let activationEnds = diagram.items.filter { if case .activationEnd = $0 { true } else { false } }
        XCTAssertEqual(activationStarts.count, 1)
        XCTAssertEqual(activationEnds.count, 1)
    }

    func testSuffixActivation() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>+John: Activate
            John-->>-Alice: Deactivate
        """))
        XCTAssertTrue(diagram.messages[0].activate)
        XCTAssertTrue(diagram.messages[1].deactivate)
    }

    // MARK: - BR Tags

    func testBrTagInMessageLabel() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            A->>B: Line1<br>Line2
        """))
        XCTAssertEqual(diagram.messages.first?.label, "Line1\nLine2")
    }

    func testBrTagInActorLabel() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            participant A as First<br>Second
            A->>B: Hello
        """))
        let a = diagram.actors.first(where: { $0.id == "A" })
        XCTAssertTrue(a?.label.contains("\n") ?? false)
    }

    // MARK: - Autonumber

    func testAutonumberBasic() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            autonumber
            Alice->>Bob: One
            Alice->>Bob: Two
        """))
        XCTAssertTrue(diagram.autonumberEnabled)
        XCTAssertEqual(diagram.autonumberStart, 1.0)
        XCTAssertEqual(diagram.autonumberStep, 1.0)
    }

    func testAutonumberOff() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            autonumber off
            Alice->>Bob: Msg
        """))
        XCTAssertFalse(diagram.autonumberEnabled)
    }

    func testAutonumberWithStart() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            autonumber 10
            Alice->>Bob: Msg
        """))
        XCTAssertTrue(diagram.autonumberEnabled)
        XCTAssertEqual(diagram.autonumberStart, 10.0)
    }

    func testAutonumberWithStartAndStep() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            autonumber 10 2
            Alice->>Bob: Msg
        """))
        XCTAssertTrue(diagram.autonumberEnabled)
        XCTAssertEqual(diagram.autonumberStart, 10.0)
        XCTAssertEqual(diagram.autonumberStep, 2.0)
    }

    // MARK: - Box

    func testBoxGrouping() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            box rgb(33,66,99) Services
                participant API
                participant DB
            end
            API->>DB: Query
        """))
        XCTAssertEqual(diagram.boxes.count, 1)
        XCTAssertEqual(diagram.boxes[0].name, "Services")
        XCTAssertEqual(diagram.boxes[0].fill, "rgb(33,66,99)")
        XCTAssertEqual(diagram.boxes[0].actorIds, ["API", "DB"])
    }

    // MARK: - Control Structures

    func testLoopBlock() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            loop Every minute
                Alice->>Bob: Hello
            end
        """))
        let blocks = diagram.blocks
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, "loop")
        XCTAssertEqual(blocks[0].label, "Every minute")
    }

    func testAltWithElse() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            alt Success
                Alice->>Bob: OK
            else Failure
                Alice->>Bob: Error
            end
        """))
        let blocks = diagram.blocks
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, "alt")
        XCTAssertEqual(blocks[0].dividers.count, 1)
    }

    func testCriticalWithOption() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            critical Perform check
                A->>B: Check
            option Timeout
                A-xB: Fail
            end
        """))
        let blocks = diagram.blocks
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, "critical")
        XCTAssertEqual(blocks[0].dividers.count, 1)
    }

    func testNestedBlocks() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            loop Outer
                alt Inner
                    Alice->>Bob: Hey
                end
            end
        """))
        let blocks = diagram.blocks
        XCTAssertGreaterThanOrEqual(blocks.count, 2)
    }

    // MARK: - Title and Accessibility

    func testTitle() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            title My Sequence Diagram
            Alice->>Bob: Hello
        """))
        XCTAssertEqual(diagram.title, "My Sequence Diagram")
    }

    func testAccTitle() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            accTitle: Accessible Title
            Alice->>Bob: Hello
        """))
        XCTAssertEqual(diagram.accTitle, "Accessible Title")
    }

    func testAccDescr() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            accDescr: A description of this diagram
            Alice->>Bob: Hello
        """))
        XCTAssertEqual(diagram.accDescr, "A description of this diagram")
    }

    // MARK: - Links and Interactivity

    func testLinkStatement() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            link Alice: Dashboard @ https://example.com
            Alice->>Bob: Hello
        """))
        let linkItems = diagram.items.filter { if case .link = $0 { true } else { false } }
        XCTAssertEqual(linkItems.count, 1)
    }

    func testPropertiesStatement() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            properties Svc: {"class": "internal"}
            Svc->>DB: Query
        """))
        let propItems = diagram.items.filter { if case .properties = $0 { true } else { false } }
        XCTAssertEqual(propItems.count, 1)
    }

    // MARK: - Case Insensitive

    func testCaseInsensitiveKeywords() throws {
        let diagram = try parseSequenceDiagram(lines("""
        SequenceDiagram
            PARTICIPANT Alice
            ACTOR Bob
            LOOP Every minute
                Alice->>Bob: Hello
            END
            NOTE left of Alice: A note
        """))
        XCTAssertEqual(diagram.actors.count, 2)
        XCTAssertEqual(diagram.blocks.count, 1)
        XCTAssertEqual(diagram.notes.count, 1)
    }

    // MARK: - Entity Decoding

    func testEntityDecoding() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Hello #infin; World
        """))
        XCTAssertEqual(diagram.messages.first?.label, "Hello ∞ World")
    }

    func testDecimalEntityDecoding() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Heart #9829;
        """))
        XCTAssertEqual(diagram.messages.first?.label, "Heart ♥")
    }

    // MARK: - URL Sanitization

    func testLinkSanitizationBlocksJavascript() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            link Alice: Bad @ javascript:alert(1)
            Alice->>Bob: Hello
        """))
        let linkItems = diagram.items.filter { if case .link = $0 { true } else { false } }
        XCTAssertEqual(linkItems.count, 0, "javascript: URLs should be blocked")
    }

    func testLinkSanitizationBlocksDataUri() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            link Alice: Bad @ data:text/html,<script>alert(1)</script>
            Alice->>Bob: Hello
        """))
        let linkItems = diagram.items.filter { if case .link = $0 { true } else { false } }
        XCTAssertEqual(linkItems.count, 0, "data: URLs should be blocked")
    }

    func testLinkSanitizationAllowsHttps() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            link Alice: Dashboard @ https://example.com
            Alice->>Bob: Hello
        """))
        let linkItems = diagram.items.filter { if case .link = $0 { true } else { false } }
        XCTAssertEqual(linkItems.count, 1, "https: URLs should be allowed")
    }

    func testLinkSanitizationAllowsMailto() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            link Alice: Email @ mailto:alice@example.com
            Alice->>Bob: Hello
        """))
        let linkItems = diagram.items.filter { if case .link = $0 { true } else { false } }
        XCTAssertEqual(linkItems.count, 1, "mailto: URLs should be allowed")
    }

    func testLinkSanitizationBlocksVbscript() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            link Alice: Bad @ vBScript:msgbox(1)
            Alice->>Bob: Hello
        """))
        let linkItems = diagram.items.filter { if case .link = $0 { true } else { false } }
        XCTAssertEqual(linkItems.count, 0, "vbscript: URLs should be blocked")
    }

    // MARK: - Notes

    func testNoteLeftOf() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Hello
            Note left of Alice: A note
        """))
        XCTAssertEqual(diagram.notes.count, 1)
        XCTAssertEqual(diagram.notes[0].position, "left")
        XCTAssertEqual(diagram.notes[0].actorIds, ["Alice"])
    }

    func testNoteOver() throws {
        let diagram = try parseSequenceDiagram(lines("""
        sequenceDiagram
            Alice->>Bob: Hello
            Note over Alice,Bob: A note over both
        """))
        XCTAssertEqual(diagram.notes.count, 1)
        XCTAssertEqual(diagram.notes[0].position, "over")
        XCTAssertEqual(diagram.notes[0].actorIds, ["Alice", "Bob"])
    }

    // MARK: - PositionedSequenceDiagram backward compat

    func testSequenceDiagramPositionedHasNewFields() throws {
        let pos = PositionedSequenceDiagram(width: 100, height: 100)
        XCTAssertEqual(pos.boxes.count, 0)
        XCTAssertEqual(pos.bottomActors.count, 0)
        XCTAssertEqual(pos.rectHighlights.count, 0)
        XCTAssertNil(pos.title)
        XCTAssertNil(pos.accTitle)
        XCTAssertNil(pos.accDescr)
    }
}
