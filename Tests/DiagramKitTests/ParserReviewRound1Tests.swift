import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// Regressions found by the review of the parser remediation (round 1).
@Suite("Parser remediation review, round 1")
struct ParserReviewRound1Tests {

    private static func flowchart(_ source: String) async throws -> ParsedGraphModel {
        let document = try await DiagramEngine.parse(source)
        guard case .flowchart(let graph) = document.payload else {
            Issue.record("expected a flowchart")
            throw CancellationError()
        }
        return graph
    }

    @Test("a linkStyle colour ending in ; is a colour, not an entity")
    func linkStyleColour() async throws {
        let graph = try await Self.flowchart("graph TD\nA-->B\nlinkStyle 0 stroke:#333;")
        #expect(graph.linkStyles[0]?["stroke"] == "#333")
    }

    @Test("style pre-pass keeps the matching semantics", arguments: [
        ("style A fill:#000;", "style A fill:#000"),
        ("classDef k fill:#f9f,stroke:#333,color:#000;", "classDef k fill:#f9f,stroke:#333,color:#000"),
        ("linkStyle 0 stroke:#333;", "linkStyle 0 stroke:#333"),
        ("style A fill: #000;", "style A fill: #000;"),
        ("A[#35;] --> B;", "A[#35;] --> B;"),
        ("style A fill:red;", "style A fill:red;"),
        ("x:#1 style y;", "x:#1 style y;"),
    ])
    func stylePrePassSemantics(_ line: String, _ expected: String) {
        #expect(_HTMLEntities.stripStyleStatementTerminators(line) == expected)
    }

    @Test("gantt flags followed by a %% comment still apply")
    func ganttFlagsWithComment() async throws {
        let document = try await DiagramEngine.parse("gantt\ndateFormat YYYY-MM-DD\ninclusiveEndDates %% inclusive\ntopAxis %% c\nTask : t1, 2024-01-01, 1d")
        guard case .gantt(let diagram) = document.payload else {
            Issue.record("expected gantt")
            return
        }
        #expect(diagram.inclusiveEndDates)
        #expect(diagram.topAxis)
        #expect(diagram.tasks.count == 1)
    }

    @Test("an unbalanced bracket in a pipe edge label does not swallow the next statement")
    func pipeLabelBracket() async throws {
        let graph = try await Self.flowchart("flowchart LR\nA -->|sad :(| B; C --> D")
        #expect(graph.edges.map { "\($0.source)->\($0.target)" } == ["A->B", "C->D"])
    }

    @Test("one-line bodies still parse after the regex was replaced")
    func oneLineBodiesStillParse() async throws {
        let state = try await DiagramEngine.parse("stateDiagram-v2\n    state Single {   a --> b   }")
        if case .stateDiagram(let graph) = state.payload {
            #expect(graph.subgraphs.map(\.id) == ["Single"])
        } else { Issue.record("expected state") }
        let cls = try await DiagramEngine.parse("classDiagram\n    class One <<interface>> { +foo() }")
        if case .classDiagram(let diagram) = cls.payload {
            #expect(diagram.classMap["One"]?.methods.map(\.id) == ["foo"])
        } else { Issue.record("expected class") }
    }

    @Test("a composite claims a block the root only mentioned earlier", arguments: [
        "block-beta\na\nblock:g\na\nend",
        "block-beta\na --> b\nblock:g\na b\nend",
    ])
    func compositeClaimsEarlierRootMention(_ source: String) async throws {
        let result = try await DiagramEngine.parseImportResult(source: source)
        guard case .block(let diagram) = result.document.payload else {
            Issue.record("expected block")
            return
        }
        #expect(diagram.blockDatabase["g"]?.children.contains("a") == true)
        #expect(diagram.blockDatabase["root"]?.children.contains("a") == false)
        #expect(diagram.rootChildren.contains("g"))
        #expect(!result.diagnostics.contains { $0.message.contains("already placed elsewhere") })
    }

    private static func node(_ graph: ParsedGraphModel, _ id: String) -> (label: String, shape: String)? {
        graph.nodesInOrder.first { $0.id == id }.map { ($0.node.label, "\($0.node.shape)") }
    }

    @Test("composites that list each other still keep one of them at the root")
    func cycleStillPlacedAtRoot() async throws {
        let result = try await DiagramEngine.parseImportResult(source: "block-beta\nblock:a\n  b\nend\nblock:b\n  a\nend")
        guard case .block(let diagram) = result.document.payload else {
            Issue.record("expected block")
            return
        }
        #expect(diagram.rootChildren == ["a"])
        #expect(diagram.blockDatabase["a"]?.children == ["b"])
        #expect(diagram.blockDatabase["b"]?.children == [])
    }
}
