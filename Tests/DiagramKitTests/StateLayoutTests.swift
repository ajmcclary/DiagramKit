import Testing
import Foundation
@testable import DiagramKitModel

private enum StateLayoutTestError: Error {
    case notAStateDiagram
    case notStateContent
}

private func layoutState(_ source: String) throws -> PositionedGraph {
    let (doc, _) = try parseMermaid(source)
    guard case .stateDiagram = doc.payload else {
        throw StateLayoutTestError.notAStateDiagram
    }
    return try layoutGraphSync(doc)
}

@Suite(.serialized)
@MainActor
struct StateLayoutTests {

    @Test func basicChainHasPositiveBounds() throws {
        let positioned = try layoutState("""
        stateDiagram-v2
            [*] --> S1
            S1 --> S2
            S2 --> [*]
        """)
        #expect(positioned.width > 0)
        #expect(positioned.height > 0)
    }

    @Test func contentIsStateDiagramCase() throws {
        let positioned = try layoutState("""
        stateDiagram-v2
            [*] --> A
        """)
        guard case .stateDiagram = positioned.content else {
            Issue.record("Expected .stateDiagram content case")
            return
        }
    }

    @Test func startPseudostateCarriesStateStartShapeString() throws {
        let positioned = try layoutState("""
        stateDiagram-v2
            [*] --> A
        """)
        let nodes = positioned.flowchartNodes ?? []
        let start = nodes.first { $0.id == "root_start" }
        #expect(start != nil)
        #expect(start?.shape == "state-start")
        #expect((start?.width ?? 0) > 0)
        #expect((start?.height ?? 0) > 0)
    }

    @Test func endPseudostateCarriesStateEndShapeString() throws {
        let positioned = try layoutState("""
        stateDiagram-v2
            A --> [*]
        """)
        let end = positioned.flowchartNodes?.first { $0.id == "root_end" }
        #expect(end?.shape == "state-end")
    }

    @Test func choiceForkJoinShapesArePreservedThroughLayout() throws {
        let positioned = try layoutState("""
        stateDiagram-v2
            state choice_s <<choice>>
            state fork_s <<fork>>
            state join_s <<join>>
            [*] --> choice_s
            choice_s --> fork_s
            fork_s --> join_s
            join_s --> [*]
        """)
        let nodes = positioned.flowchartNodes ?? []
        #expect(nodes.first(where: { $0.id == "choice_s" })?.shape == "choice")
        #expect(nodes.first(where: { $0.id == "fork_s" })?.shape == "fork")
        #expect(nodes.first(where: { $0.id == "join_s" })?.shape == "join")
    }

    @Test func compositeStateProducesGroupEnclosingChildren() throws {
        let positioned = try layoutState("""
        stateDiagram-v2
            state Active {
                A --> B
            }
            [*] --> Active
        """)
        let groups = positioned.flowchartGroups ?? []
        let active = groups.first { $0.id == "Active" }
        #expect(active != nil)
        #expect((active?.width ?? 0) > 0)
        #expect((active?.height ?? 0) > 0)
    }

    @Test func multiTransitionEdgesProduceNonDegenerateRoutes() throws {
        let positioned = try layoutState("""
        stateDiagram-v2
            [*] --> A
            A --> B
            B --> [*]
        """)
        let edges = positioned.flowchartEdges ?? []
        #expect(edges.count == 3)
        for edge in edges {
            #expect(edge.points.count >= 2)
        }
    }

    @Test func layoutIsDeterministic() throws {
        let source = """
        stateDiagram-v2
            [*] --> A
            A --> B
            B --> [*]
        """
        let a = try layoutState(source)
        let b = try layoutState(source)
        #expect(a.width == b.width)
        #expect(a.height == b.height)
        let aIds = (a.flowchartNodes ?? []).map(\.id)
        let bIds = (b.flowchartNodes ?? []).map(\.id)
        #expect(aIds == bIds)
    }

    @Test func emptyStateDiagramLaysOutWithoutThrow() throws {
        let positioned = try layoutState("stateDiagram-v2")
        guard case .stateDiagram(let nodes, let edges, let groups) = positioned.content else {
            Issue.record("Expected .stateDiagram content case")
            return
        }
        #expect(nodes.isEmpty)
        #expect(edges.isEmpty)
        #expect(groups.isEmpty)
    }

    @Test func stateLayoutEmitsNoDiagnosticsForCanonicalSource() throws {
        let positioned = try layoutState("""
        stateDiagram-v2
            [*] --> A
            A --> B
            B --> [*]
        """)
        // Pins current behavior: canonical state sources don't drop into the
        // layout-tier diagnostic channel. Surfacing a diagnostic here would
        // mean a fallback was taken; regressing into one warrants attention.
        #expect(positioned.diagnostics.isEmpty)
    }
}
