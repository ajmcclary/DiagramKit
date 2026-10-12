#if canImport(UIKit) || canImport(AppKit)
import XCTest
import Foundation
import DiagramKitTestSupport
@testable import DiagramKit

/// REVIEW.md H3 regression guard: sequence-ASCII blocks (loop/alt boxes)
/// and notes must render at their message-aligned positions. Before the
/// item-index → message-index fix, `loop … end` + `Note over …` rendered
/// with NO box and NO note, and the broken output was pinned in the
/// seq-7-loop / seq-8-alt-else / seq-12-notes baselines.
final class SequenceAsciiStructuralTests: XCTestCase {

    private static func loadCorpus() throws -> [CorpusEntry] {
        setenv("DIAGRAMKIT_GANTT_TODAY", "2024-06-15", 1)
        return try DiagramCorpus.load()
    }

    private static func ascii(for source: String) async throws -> String {
        try await DiagramEngine.renderASCII(source: source).text
    }

    /// The H3 repro: a loop block wrapping a message plus a note over an
    /// actor must render BOTH the loop box header and the note text.
    func testLoopBlockAndNoteBothRender() async throws {
        let text = try await Self.ascii(for: """
        sequenceDiagram
          Alice->>Bob: Ping
          loop Every minute
            Bob-->>Alice: Pong
          end
          Note over Alice: Standing by
        """)
        XCTAssertTrue(text.contains("loop [Every minute"), "loop box header missing:\n\(text)")
        XCTAssertTrue(text.contains("Standing by"), "note text missing:\n\(text)")
        // The box border rows around the wrapped messages must exist.
        XCTAssertTrue(text.contains("┌") || text.contains("+"), "no block border drawn:\n\(text)")
    }

    func testSeq7LoopCorpusEntry() async throws {
        let entry = try XCTUnwrap(Self.loadCorpus().first(where: { $0.id == "seq-7-loop" }))
        let text = try await Self.ascii(for: entry.source)
        XCTAssertTrue(text.contains("loop [Every 30s]"), "loop box header missing:\n\(text)")
        XCTAssertTrue(text.contains("Connect"), "message missing:\n\(text)")
        XCTAssertTrue(text.contains("Heartbeat"), "message inside loop missing:\n\(text)")
        XCTAssertTrue(text.contains("Ack"), "message inside loop missing:\n\(text)")
    }

    func testSeq8AltElseCorpusEntry() async throws {
        let entry = try XCTUnwrap(Self.loadCorpus().first(where: { $0.id == "seq-8-alt-else" }))
        let text = try await Self.ascii(for: entry.source)
        XCTAssertTrue(text.contains("alt [Valid credentials]"), "alt box header missing:\n\(text)")
        XCTAssertTrue(text.contains("[Invalid]"), "first divider label missing:\n\(text)")
        XCTAssertTrue(text.contains("[Account locked]"), "second divider label missing:\n\(text)")
        XCTAssertTrue(text.contains("401 Unauthorized"), "else-branch message missing:\n\(text)")
        XCTAssertTrue(text.contains("403 Forbidden"), "second else-branch message missing:\n\(text)")
    }

    func testSeq12NotesCorpusEntry() async throws {
        let entry = try XCTUnwrap(Self.loadCorpus().first(where: { $0.id == "seq-12-notes" }))
        let text = try await Self.ascii(for: entry.source)
        XCTAssertTrue(text.contains("Alice prepares"), "first note missing:\n\(text)")
        XCTAssertTrue(text.contains("Bob thinks"), "second note missing:\n\(text)")
        XCTAssertTrue(text.contains("Conversation complete"), "over-note missing:\n\(text)")
    }
}
#endif
