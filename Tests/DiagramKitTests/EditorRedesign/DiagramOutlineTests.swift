import Testing
@testable import DiagramKit
@testable import DiagramKitModel
@testable import DiagramKitSample

@Suite struct DiagramOutlineTests {
    @Test func nestsNodesUnderSubgraphs() async throws {
        let source = """
        flowchart TB
          subgraph Ingest
            A[Start] --> B[Process]
          end
          subgraph Output
            C[End]
          end
          B --> C
        """
        let doc = try await DiagramEngine.parse(source)
        guard case .flowchart(let model) = doc.payload else {
            Issue.record("expected flowchart payload")
            return
        }
        let tree = OutlineTree.fromGraph(model)

        // Two top-level subgraphs; every root is a subgraph (no loose nodes).
        let subgraphRoots = tree.roots.filter { $0.kind == .subgraph }
        #expect(subgraphRoots.count == 2)
        #expect(tree.roots.allSatisfy { $0.kind == .subgraph })

        // Ingest nests A and B as node children.
        let ingest = subgraphRoots.first { $0.id == "Ingest" || $0.label == "Ingest" }
        #expect(ingest != nil)
        let ingestNodeIDs = Set((ingest?.children ?? []).filter { $0.kind == .node }.map(\.id))
        #expect(ingestNodeIDs.contains("A"))
        #expect(ingestNodeIDs.contains("B"))

        #expect(tree.edges.count >= 2)
    }

    @Test func flatWhenNoSubgraphs() async throws {
        let doc = try await DiagramEngine.parse("flowchart TB\n A[Start] --> B[Process] --> C[End]")
        guard case .flowchart(let model) = doc.payload else {
            Issue.record("expected flowchart payload")
            return
        }
        let tree = OutlineTree.fromGraph(model)
        #expect(tree.roots.count == 3)
        #expect(tree.roots.allSatisfy { $0.kind == .node })
        #expect(tree.roots.map(\.id) == ["A", "B", "C"])
    }
}
