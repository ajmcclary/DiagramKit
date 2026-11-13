import Foundation
import Testing
import DiagramKit
import DiagramKitModel

// Owner ruling on pkg-diagram-parsers-20: match upstream Mermaid. In
// unquoted state or sequence text after `:`, `%%` is text; a `%%` at the
// start of a line (after optional whitespace) is still a comment.

@Suite("%% in state and sequence description text")
struct DescriptionPercentCommentTests {

    @Test("a state transition label keeps %%")
    func stateLabel() throws {
        guard case .stateDiagram(let g) = try DiagramPipeline.parse("stateDiagram-v2\n  s1 --> s2 : 50%% chance\n").payload else {
            Issue.record("not a state graph"); return
        }
        #expect(g.edges.first?.label == "50%% chance")
    }

    @Test("a sequence message keeps %%")
    func sequenceMessage() throws {
        guard case .sequenceDiagram(let model) = try DiagramPipeline.parse("sequenceDiagram\n  Alice->>Bob: 50%% chance\n").payload else {
            Issue.record("not a sequence"); return
        }
        #expect(model.messages.first?.label == "50%% chance")
    }

    @Test("a line starting with %% is a comment", arguments: [
        "stateDiagram-v2\n  %% s9 --> s10 : not an edge\n  s1 --> s2\n",
        "stateDiagram-v2\n%% s9 --> s10 : not an edge\n  s1 --> s2\n",
    ])
    func stateLineComment(_ source: String) throws {
        guard case .stateDiagram(let g) = try DiagramPipeline.parse(source).payload else {
            Issue.record("not a state graph"); return
        }
        #expect(g.edges.count == 1)
        #expect(!g.nodesInOrder.contains { $0.id == "s9" })
    }

    @Test("a sequence line starting with %% is a comment")
    func sequenceLineComment() throws {
        guard case .sequenceDiagram(let model) = try DiagramPipeline.parse("sequenceDiagram\n  %% Carol->>Dave: no\n  Alice->>Bob: hi\n").payload else {
            Issue.record("not a sequence"); return
        }
        #expect(model.messages.count == 1)
        #expect(!model.actors.contains { $0.id == "Carol" })
    }

    @Test("%% before the colon still starts a comment")
    func beforeColon() throws {
        guard case .stateDiagram(let g) = try DiagramPipeline.parse("stateDiagram-v2\n  s1 --> s2 %% trailing : note\n").payload else {
            Issue.record("not a state graph"); return
        }
        #expect(g.edges.count == 1)
        #expect(g.edges.first?.label == nil)
    }
}
