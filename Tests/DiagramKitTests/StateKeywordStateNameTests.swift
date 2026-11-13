import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitModel

/// A transition makes both operands states, whatever their names.
@Suite("State names that look like keywords")
struct StateKeywordStateNameTests {

    @Test("Start --> End and Left --> Right create every state")
    func keywordNamedStatesExist() async throws {
        let document = try await DiagramEngine.parse("""
        stateDiagram-v2
            [*] --> Start
            Start --> End
            End --> [*]
            Left --> Right
        """)
        guard case .stateDiagram(let graph) = document.payload else {
            Issue.record("expected a state diagram")
            return
        }
        let ids = Set(graph.nodesInOrder.map(\.id))
        for name in ["Start", "End", "Left", "Right"] {
            #expect(ids.contains(name), "missing state \(name)")
        }
        for edge in graph.edges {
            #expect(ids.contains(edge.source) && ids.contains(edge.target), "dangling edge \(edge.source) -> \(edge.target)")
        }
    }

    @Test("a lowercase keyword line is still a statement, not a state")
    func lowercaseKeywordStatement() async throws {
        let document = try await DiagramEngine.parse("stateDiagram-v2\n    a --> b\n    direction LR")
        guard case .stateDiagram(let graph) = document.payload else {
            Issue.record("expected a state diagram")
            return
        }
        #expect(Set(graph.nodesInOrder.map(\.id)) == ["a", "b"])
    }
}
