import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// One-line bodies and unclosed blocks are parsed or reported, never
/// dropped silently (2026-11-12 parser review).
@Suite("Single-line bodies and unclosed blocks")
struct SingleLineBodyTests {

    @Test("a one-line class body creates the class and its member")
    func oneLineClassBody() async throws {
        let document = try await DiagramEngine.parse("classDiagram\n    class One { +foo() }\n    namespace Zoo {\n        class Tiger { +roar() }\n    }")
        guard case .classDiagram(let diagram) = document.payload else {
            Issue.record("expected a class diagram")
            return
        }
        #expect(diagram.classMap["One"]?.methods.map(\.id) == ["foo"])
        #expect(diagram.classMap["Tiger"]?.methods.map(\.id) == ["roar"])
    }

    @Test("a one-line composite state body creates the composite and its states")
    func oneLineStateBody() async throws {
        let document = try await DiagramEngine.parse("stateDiagram-v2\n    state Single { a --> b }")
        guard case .stateDiagram(let graph) = document.payload else {
            Issue.record("expected a state diagram")
            return
        }
        #expect(graph.subgraphs.map(\.id) == ["Single"])
        #expect(Set(graph.nodesInOrder.map(\.id)).isSuperset(of: ["a", "b"]))
        #expect(graph.edges.contains { $0.source == "a" && $0.target == "b" })
    }

    @Test("an unrecognised state statement is reported, not silently dropped")
    func unrecognisedStateStatement() async throws {
        let result = try await DiagramEngine.parseImportResult(source: "stateDiagram-v2\n    s1 --> my-state")
        #expect(result.diagnostics.contains { $0.message.contains("not recognised") })
    }

    @Test("an unclosed subgraph is kept and reported")
    func unclosedSubgraph() async throws {
        let result = try await DiagramEngine.parseImportResult(source: "flowchart TD\n    subgraph S\n    a --> b")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("expected a flowchart")
            return
        }
        #expect(graph.subgraphs.map(\.id) == ["S"])
        #expect(result.diagnostics.contains { $0.message.contains("no matching end") })
    }

    @Test("an unclosed composite state is kept and reported")
    func unclosedComposite() async throws {
        let result = try await DiagramEngine.parseImportResult(source: "stateDiagram-v2\n    state C {\n    a --> b")
        guard case .stateDiagram(let graph) = result.document.payload else {
            Issue.record("expected a state diagram")
            return
        }
        #expect(graph.subgraphs.map(\.id) == ["C"])
        #expect(result.diagnostics.contains { $0.message.contains("no closing }") })
    }
}
