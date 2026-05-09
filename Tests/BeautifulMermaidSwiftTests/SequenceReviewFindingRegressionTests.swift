import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

final class SequenceReviewFindingRegressionTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
    }

    private func parse(_ source: String) throws -> SequenceDiagram {
        try parseSequenceDiagram(lines(source))
    }

    func testMermaidHalfArrowSyntaxParses() throws {
        let diagram = try parse("""
        sequenceDiagram
            A-|\\B: top half
            A-|/B: bottom half
            A/|--B: reverse top dotted
            A\\|--B: reverse bottom dotted
        """)

        XCTAssertEqual(diagram.messages.map(\.arrowType), [
            .solidArrowTop,
            .solidArrowBottom,
            .solidArrowTopReverseDotted,
            .solidArrowBottomReverseDotted,
        ])
    }

    func testDedicatedActivationStatementsProduceActivationLayout() throws {
        let diagram = try parse("""
        sequenceDiagram
            participant Alice
            participant John
            Alice->>John: Hello
            activate John
            John-->>Alice: Hi
            deactivate John
        """)

        let positioned = try layoutSequenceDiagram(diagram)

        XCTAssertEqual(positioned.activations.count, 1)
        let activation = try XCTUnwrap(positioned.activations.first)
        XCTAssertEqual(activation.actorId, "John")
        XCTAssertLessThan(activation.topY, activation.bottomY)
    }

    func testRectBlockBecomesBackgroundHighlight() throws {
        let diagram = try parse("""
        sequenceDiagram
            rect rgba(0, 0, 255, .1)
                A->>B: highlighted
            end
        """)

        XCTAssertEqual(diagram.blocks.count, 1)
        XCTAssertTrue(diagram.blocks[0].isHighlight)
        XCTAssertEqual(diagram.blocks[0].highlightFill, "rgba(0, 0, 255, .1)")

        let positioned = try layoutSequenceDiagram(diagram)
        XCTAssertEqual(positioned.rectHighlights.count, 1)
        let rect = try XCTUnwrap(positioned.rectHighlights.first)
        XCTAssertEqual(rect.fill, "rgba(0, 0, 255, .1)")
    }

    func testCreatedAndDestroyedActorLifecycleAffectsLayout() throws {
        let diagram = try parse("""
        sequenceDiagram
            A->>B: first
            create participant C
            B->>C: create
            C->>B: reply
            destroy C
            C-xB: destroyed
            A->>B: after
        """)

        let positioned = try layoutSequenceDiagram(diagram)
        let topActor = try XCTUnwrap(positioned.actors.first(where: { $0.id == "A" }))
        let createdActor = try XCTUnwrap(positioned.actors.first(where: { $0.id == "C" }))
        let createdLifeline = try XCTUnwrap(positioned.lifelines.first(where: { $0.actorId == "C" }))
        let destroyMessage = try XCTUnwrap(positioned.messages.first(where: { $0.label == "destroyed" }))

        XCTAssertGreaterThan(createdActor.y, topActor.y + 20)
        XCTAssertGreaterThan(createdLifeline.topY, topActor.y + topActor.height)
        XCTAssertEqual(createdLifeline.bottomY, destroyMessage.y, accuracy: 0.001)
    }

    func testOrderedAutonumberEventsAffectOnlyFollowingMessages() throws {
        let diagram = try parse("""
        sequenceDiagram
            autonumber 10 2
            A->>B: one
            autonumber off
            A->>B: two
            autonumber 1
            A->>B: three
        """)

        let positioned = try layoutSequenceDiagram(diagram)

        XCTAssertEqual(positioned.messages[0].sequenceNumber, 10)
        XCTAssertTrue(positioned.messages[0].sequenceVisible)
        XCTAssertNil(positioned.messages[1].sequenceNumber)
        XCTAssertFalse(positioned.messages[1].sequenceVisible)
        XCTAssertEqual(positioned.messages[2].sequenceNumber, 1)
        XCTAssertTrue(positioned.messages[2].sequenceVisible)
    }

    func testLinkPropertyAndDetailStatementsFoldIntoActors() throws {
        let diagram = try parse("""
        sequenceDiagram
            participant Svc
            link Svc: Dashboard @ https://example.com
            links Svc: {"Logs": "https://logs.example.com"}
            properties Svc: {"class": "internal", "icon": "@clock"}
            details Svc: elementId
            Svc->>DB: Query
        """)

        let service = try XCTUnwrap(diagram.actors.first(where: { $0.id == "Svc" }))

        XCTAssertEqual(service.links["Dashboard"], "https://example.com")
        XCTAssertEqual(service.links["Logs"], "https://logs.example.com")
        XCTAssertEqual(service.properties["class"], "internal")
        XCTAssertEqual(service.properties["icon"], "@clock")
        XCTAssertEqual(service.detailsElementId, "elementId")
    }

    func testParticipantRedeclarationUpdatesImplicitActor() throws {
        let diagram = try parse("""
        sequenceDiagram
            Alice->>Bob: Hello
            participant Bob as Robert
            Bob->>Alice: Hi
        """)

        let bob = try XCTUnwrap(diagram.actors.first(where: { $0.id == "Bob" }))
        XCTAssertEqual(bob.label, "Robert")
        XCTAssertEqual(diagram.actors.filter { $0.id == "Bob" }.count, 1)
    }
}
