import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitModel

/// Only `"` quotes mindmap node text; apostrophes and `%%` inside a shape
/// are text.
@Suite("Mindmap apostrophes and percent signs")
struct MindmapApostropheTests {

    private static func descriptions(_ source: String) async throws -> [String] {
        let document = try await DiagramEngine.parse(source)
        guard case .mindmap(let diagram) = document.payload else {
            Issue.record("expected a mindmap")
            return []
        }
        func walk(_ node: MindmapNode) -> [String] { [node.descr] + node.children.flatMap(walk) }
        return diagram.root.map(walk) ?? []
    }

    @Test("an apostrophe in a shaped node does not fail the diagram")
    func apostropheDoesNotFail() async throws {
        let labels = try await Self.descriptions("""
        mindmap
          root((Team goals))
            id[User's Guide]
            child2
            child3
        """)
        #expect(labels == ["Team goals", "User's Guide", "child2", "child3"])
    }

    @Test("apostrophes in sibling nodes do not merge the lines between them")
    func apostrophesDoNotMergeLines() async throws {
        let labels = try await Self.descriptions("""
        mindmap
          root
            a[Bob's plan]
            b[middle]
            c[Alice's plan]
            d[last]
        """)
        #expect(labels == ["root", "Bob's plan", "middle", "Alice's plan", "last"])
    }

    @Test("%% inside a shaped node is text; a trailing %% is still a comment")
    func percentInsideShape() async throws {
        let labels = try await Self.descriptions("mindmap\n  root\n    a[100%% done] %% note")
        #expect(labels == ["root", "100%% done"])
    }

    @Test("double-quoted node text still parses")
    func doubleQuotedText() async throws {
        let labels = try await Self.descriptions("mindmap\n  root\n    a[\"quoted (text)\"]")
        #expect(labels == ["root", "quoted (text)"])
    }
}
