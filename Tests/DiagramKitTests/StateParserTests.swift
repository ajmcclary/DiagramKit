import Testing
import Foundation
@testable import DiagramKitModel

private func stateModel(_ source: String) throws -> original_src_types.MermaidGraph {
    let (doc, _) = try parseMermaid(source)
    guard case .stateDiagram(let model) = doc.payload else {
        throw StateTestError.notAStateDiagram
    }
    return model
}

private enum StateTestError: Error {
    case notAStateDiagram
}

struct StateParserTests {

    // MARK: - Header acceptance

    @Test func parsesV2Header() throws {
        let model = try stateModel("""
        stateDiagram-v2
            [*] --> S1
            S1 --> [*]
        """)
        #expect(model.nodesInOrder.count >= 3)
        #expect(model.edges.count == 2)
    }

    @Test func parsesV1Header() throws {
        let model = try stateModel("""
        stateDiagram
            [*] --> S1
            S1 --> [*]
        """)
        #expect(model.nodesInOrder.count >= 3)
        #expect(model.edges.count == 2)
    }

    // MARK: - Linear transitions

    @Test func parsesSimpleStateChain() throws {
        let model = try stateModel("""
        stateDiagram-v2
            [*] --> S1
            S1 --> S2
            S2 --> [*]
        """)
        let ids = model.nodesInOrder.map(\.id)
        #expect(ids.contains("S1"))
        #expect(ids.contains("S2"))
        #expect(model.edges.count == 3)
    }

    // MARK: - Pseudostates

    @Test func startPseudostateGetsStateStartShape() throws {
        let model = try stateModel("""
        stateDiagram-v2
            [*] --> A
        """)
        let start = model.nodesById["root_start"]
        #expect(start != nil)
        #expect(start?.shape == .stateStart)
    }

    @Test func endPseudostateGetsStateEndShape() throws {
        let model = try stateModel("""
        stateDiagram-v2
            A --> [*]
        """)
        let end = model.nodesById["root_end"]
        #expect(end != nil)
        #expect(end?.shape == .stateEnd)
    }

    @Test func choicePseudostateGetsChoiceShape() throws {
        let model = try stateModel("""
        stateDiagram-v2
            state if_state <<choice>>
            [*] --> if_state
        """)
        let node = model.nodesById["if_state"]
        #expect(node?.shape == .choice)
    }

    @Test func forkPseudostateGetsForkShape() throws {
        let model = try stateModel("""
        stateDiagram-v2
            state fork_state <<fork>>
            [*] --> fork_state
        """)
        let node = model.nodesById["fork_state"]
        #expect(node?.shape == .fork)
    }

    @Test func joinPseudostateGetsJoinShape() throws {
        let model = try stateModel("""
        stateDiagram-v2
            state join_state <<join>>
            join_state --> [*]
        """)
        let node = model.nodesById["join_state"]
        #expect(node?.shape == .join)
    }

    // MARK: - Composite states

    @Test func compositeStateBecomesSubgraph() throws {
        let model = try stateModel("""
        stateDiagram-v2
            state Active {
                A --> B
            }
        """)
        #expect(model.subgraphs.count >= 1)
        let composite = model.subgraphs.first { $0.id == "Active" }
        #expect(composite != nil)
        #expect(composite?.nodeIds.contains("A") == true)
        #expect(composite?.nodeIds.contains("B") == true)
    }

    @Test func nestedCompositeStatePreservesHierarchy() throws {
        let model = try stateModel("""
        stateDiagram-v2
            state Outer {
                state Inner {
                    X --> Y
                }
            }
        """)
        let outer = model.subgraphs.first { $0.id == "Outer" }
        #expect(outer != nil)
        #expect(outer?.children.contains(where: { $0.id == "Inner" }) == true)
    }

    @Test func concurrencyDividerInsideCompositeParsesAsRegions() throws {
        let model = try stateModel("""
        stateDiagram-v2
            state Composite {
                [*] --> A1
                --
                [*] --> B1
            }
        """)
        let composite = model.subgraphs.first { $0.id == "Composite" }
        #expect(composite != nil)
        // Concurrent regions land as child subgraphs of the composite.
        #expect(composite?.children.isEmpty == false)
    }

    // MARK: - Notes

    @Test func noteLeftOfCreatesStateNoteNode() throws {
        let model = try stateModel("""
        stateDiagram-v2
            S1 : Active
            note left of S1
                Important note text
            end note
        """)
        let noteNode = model.nodesInOrder.first { $0.node.shape == .stateNote }
        #expect(noteNode != nil)
    }

    @Test func noteAttachedViaDottedEdge() throws {
        let model = try stateModel("""
        stateDiagram-v2
            S1 : Active
            note right of S1
                Hello
            end note
        """)
        let dotted = model.edges.first { $0.style == .dotted }
        #expect(dotted != nil)
    }

    // MARK: - Multi-line descriptions

    @Test func multilineDescriptionPopulatesDescriptions() throws {
        let model = try stateModel("""
        stateDiagram-v2
            S1 : First line
            S1 : Second line
        """)
        let node = model.nodesById["S1"]
        #expect(node != nil)
        #expect(node!.descriptions.count >= 1)
    }

    // MARK: - Class / style / click directives

    @Test func classDefRegistersInGraphClassDefs() throws {
        let model = try stateModel("""
        stateDiagram-v2
            classDef important fill:#f96,stroke:#333
            class A important
            [*] --> A
        """)
        #expect(model.classDefs["important"] != nil)
        #expect(model.classAssignments["A"]?.contains("important") == true)
    }

    @Test func clickDirectivePopulatesNodeInteractions() throws {
        let model = try stateModel("""
        stateDiagram-v2
            [*] --> A
            click A href "https://example.com"
        """)
        #expect(model.nodeInteractions["A"] != nil)
    }

    // MARK: - Accessibility metadata

    @Test func accTitleAndAccDescrPopulate() throws {
        let model = try stateModel("""
        stateDiagram-v2
            accTitle: State machine title
            accDescr: Describes the state machine
            [*] --> A
        """)
        #expect(model.accTitle == "State machine title")
        #expect(model.accDescr == "Describes the state machine")
    }

    // MARK: - Empty source / comments

    @Test func emptyHeaderOnlyParsesToEmptyGraph() throws {
        let model = try stateModel("stateDiagram-v2")
        #expect(model.nodesInOrder.isEmpty)
        #expect(model.edges.isEmpty)
    }

    @Test func commentsIgnored() throws {
        let model = try stateModel("""
        stateDiagram-v2
            %% This is a comment
            [*] --> A
            %% Another comment
            A --> [*]
        """)
        #expect(model.edges.count == 2)
    }
}
