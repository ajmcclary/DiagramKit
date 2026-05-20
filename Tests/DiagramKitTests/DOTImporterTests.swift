import Testing
@testable import DiagramKit
import DiagramKitModel
import DiagramKitImport
import DiagramKitGraphviz

@Suite struct DOTImporterTests {

    // MARK: - supports

    @Test("supports returns true for digraph")
    func supportsDigraph() {
        let importer = GraphvizImporter()
        #expect(importer.supports(source: "digraph G { A -> B }"))
    }

    @Test("supports returns true for graph")
    func supportsGraph() {
        let importer = GraphvizImporter()
        #expect(importer.supports(source: "graph G { A -- B }"))
    }

    @Test("supports returns true for strict digraph")
    func supportsStrictDigraph() {
        let importer = GraphvizImporter()
        #expect(importer.supports(source: "strict digraph G { }"))
    }

    @Test("supports compact digraph header")
    func supportsCompactDigraphHeader() {
        let importer = GraphvizImporter()
        #expect(importer.supports(source: "digraph{A->B}"))
    }

    @Test("supports rejects Mermaid graph TD")
    func rejectsMermaidGraphTD() {
        let importer = GraphvizImporter()
        #expect(!importer.supports(source: "graph TD\nA-->B"))
    }

    @Test("supports rejects bare edge")
    func rejectsBareEdge() {
        let importer = GraphvizImporter()
        #expect(!importer.supports(source: "A -> B"))
    }

    @Test("supports rejects D2 source")
    func rejectsD2Source() {
        let importer = GraphvizImporter()
        #expect(!importer.supports(source: "A: Start\nA -> B"))
    }

    @Test("supports rejects PlantUML")
    func rejectsPlantUML() {
        let importer = GraphvizImporter()
        #expect(!importer.supports(source: "@startuml\nAlice -> Bob: Hello\n@enduml"))
    }

    @Test("supports rejects Structurizr")
    func rejectsStructurizr() {
        let importer = GraphvizImporter()
        #expect(!importer.supports(source: "workspace { model { user = person } }"))
    }

    // MARK: - Basic properties

    @Test("supportedDiagramTypes covers flowchart, classDiagram, stateDiagram, erDiagram, architecture")
    func supportedDiagramTypesIsFlowchart() {
        let importer = GraphvizImporter()
        #expect(importer.supportedDiagramTypes == [.flowchart, .classDiagram, .stateDiagram, .erDiagram, .architecture])
    }

    @Test("name is Graphviz")
    func nameIsGraphviz() {
        let importer = GraphvizImporter()
        #expect(importer.name == "Graphviz")
    }

    // MARK: - parse: nodes

    @Test("parse returns node with correct label")
    func parseNodeLabel() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { A [label=\"Start\"]; }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.nodesInOrder.count == 1)
        #expect(graph.nodesInOrder[0].id == "A")
        #expect(graph.nodesInOrder[0].node.label == "Start")
    }

    @Test("parse synthesizes nodes for edge-only endpoints")
    func parseEdgeOnlyEndpointSynthesis() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { A -> B; }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.nodesInOrder.map(\.id) == ["A", "B"])
        #expect(graph.nodesInOrder.map(\.node.label) == ["A", "B"])
    }

    @Test("parse applies later explicit node attributes to synthesized endpoint")
    func parseExplicitNodeAttributesAfterEndpointSynthesis() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { A -> B; A [label=\"Start\", shape=circle]; }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        let node = graph.nodesInOrder.first { $0.id == "A" }?.node
        #expect(node?.label == "Start")
        #expect(node?.shape == .circle)
        #expect(!result.diagnostics.contains { $0.message.contains("Duplicate node") })
    }

    @Test("parse preserves comment markers inside quoted labels")
    func parseQuotedCommentMarkersInLabels() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { A [label=\"http://example/#section\"]; B [label=\"A # B\"]; }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.nodesInOrder.first { $0.id == "A" }?.node.label == "http://example/#section")
        #expect(graph.nodesInOrder.first { $0.id == "B" }?.node.label == "A # B")
    }

    @Test("parse returns directed edge with arrow")
    func parseDirectedEdge() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { A -> B; }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.edges.count == 1)
        #expect(graph.edges[0].source == "A")
        #expect(graph.edges[0].target == "B")
        #expect(graph.edges[0].arrowHeadEnd == .arrow)
    }

    @Test("parse returns undirected edge with no arrow")
    func parseUndirectedEdge() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("graph { A -- B; }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.edges.count == 1)
        #expect(graph.edges[0].arrowHeadEnd == .none)
    }

    @Test("parse returns multiple edges")
    func parseMultipleEdges() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { A -> B; B -> C; C -> A; }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.edges.count == 3)
    }

    @Test("parse applies default node shape")
    func parseDefaultNodeShape() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { node [shape=box]; A; }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.nodesInOrder[0].node.shape == .rectangle)
    }

    @Test("parse maps rankdir LR to direction")
    func parseRankdirLR() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { rankdir=LR; A -> B; }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.direction == .LR)
    }

    // MARK: - parse: subgraphs

    @Test("parse subgraph cluster produces subgraph")
    func parseSubgraphCluster() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { subgraph cluster_0 { A; B; } }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.subgraphs.count == 1)
        #expect(graph.subgraphs[0].id == "cluster_0")
        #expect(graph.subgraphs[0].nodeIds == ["A", "B"])
    }

    @Test("parse subgraph cluster with label")
    func parseSubgraphClusterLabel() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { subgraph cluster_0 { label=\"Group\"; A; } }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.subgraphs.count == 1)
        #expect(graph.subgraphs[0].label == "Group")
    }

    @Test("parse nested subgraphs")
    func parseNestedSubgraph() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { subgraph cluster_0 { subgraph cluster_1 { A; } } }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.subgraphs.count == 1)
        #expect(graph.subgraphs[0].children.count == 1)
        #expect(graph.subgraphs[0].children[0].id == "cluster_1")
    }

    // MARK: - parse: chained edges

    @Test("parse chained edges")
    func parseChainedEdges() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { A -> B -> C; }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.edges.count == 2)
        #expect(graph.nodesInOrder.map(\.id) == ["A", "B", "C"])
    }

    @Test("parse keeps chained edge endpoints inside containing cluster")
    func parseChainedEdgesInsideCluster() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { subgraph cluster_0 { A -> B -> C; } }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.edges.count == 2)
        #expect(graph.edges.map { "\($0.source)->\($0.target)" } == ["A->B", "B->C"])
        #expect(graph.subgraphs.count == 1)
        #expect(graph.subgraphs[0].nodeIds == ["A", "B", "C"])
    }

    // MARK: - parse: duplicates

    @Test("parse preserves duplicate edges")
    func preservesDuplicateEdges() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { A -> B; A -> B; }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.edges.count == 2)
    }

    // MARK: - Diagnostics

    @Test("parse emits diagnostic for record shape")
    func emitsDiagnosticForRecordShape() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { A [shape=record]; }")
        #expect(result.diagnostics.contains { $0.message.contains("record") || $0.message.contains("shape") })
    }

    @Test("parse emits diagnostic for color attribute")
    func emitsDiagnosticForColorAttribute() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { A [color=red]; }")
        #expect(result.diagnostics.contains { $0.message.contains("color") })
    }

    @Test("parse emits diagnostic for style filled")
    func emitsDiagnosticForStyleFilled() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { A [style=filled]; }")
        #expect(result.diagnostics.contains { $0.message.contains("style") })
    }

    @Test("parse emits diagnostic for rank same")
    func emitsDiagnosticForRankSame() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { rank=same; A; B; }")
        #expect(result.diagnostics.contains { $0.message.contains("rank") })
    }

    @Test("parse emits diagnostic for strict mode")
    func emitsDiagnosticForStrict() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("strict digraph G { A -> B }")
        #expect(result.diagnostics.contains { $0.message.contains("strict") })
    }

    @Test("parse emits diagnostic for port syntax and uses node ids")
    func emitsDiagnosticForPortSyntax() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { A:n -> B:s; }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.edges.count == 1)
        #expect(graph.edges[0].source == "A")
        #expect(graph.edges[0].target == "B")
        #expect(result.diagnostics.contains { $0.message.contains("port syntax") })
    }

    @Test("parse emits diagnostic for edge to subgraph without synthetic subgraph node")
    func emitsDiagnosticForEdgeToSubgraph() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { A -> subgraph cluster_0 { B; C; } }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.edges.isEmpty)
        #expect(graph.nodesInOrder.map(\.id) == ["A", "B", "C"])
        #expect(graph.subgraphs.count == 1)
        if graph.subgraphs.count == 1 {
            #expect(graph.subgraphs[0].id == "cluster_0")
        }
        #expect(result.diagnostics.contains { $0.message.contains("edges to subgraphs") })
    }

    // MARK: - Layout smoke

    @Test("dot layout smoke test")
    func dotLayoutSmoke() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { A [label=\"Start\"]; B [label=\"End\"]; A -> B; }")
        #expect(result.document.type == .flowchart)

        let positioned = try DiagramPipeline.layout(result.document)
        _ = positioned
        #expect(!(positioned.flowchartNodes?.isEmpty ?? true))
    }

    @Test("dot layout with cluster smoke test")
    func dotLayoutWithClusterSmoke() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("digraph { subgraph cluster_0 { A; B; } }")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.subgraphs.count == 1)

        let positioned = try DiagramPipeline.layout(result.document)
        _ = positioned
        #expect(!(positioned.flowchartNodes?.isEmpty ?? true))
    }

    @Test("dot layout with undirected smoke test")
    func dotLayoutWithUndirectedSmoke() throws {
        let importer = GraphvizImporter()
        let result = try importer.parse("graph { A -- B; }")
        #expect(result.document.type == .flowchart)

        let positioned = try DiagramPipeline.layout(result.document)
        _ = positioned
        #expect(!(positioned.flowchartNodes?.isEmpty ?? true))
    }
}
