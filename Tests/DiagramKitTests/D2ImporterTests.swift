import Testing
@testable import DiagramKit
import DiagramKitModel
import DiagramKitImport
import DiagramKitD2

@Suite struct D2ImporterTests {

    // MARK: - supports

    @Test("supports returns true for d2 source")
    func supportsReturnsTrueForD2Source() {
        let d2 = D2Importer()
        #expect(d2.supports(source: "A -> B"))
    }

    @Test("supports returns false for Mermaid graph TD source")
    func supportsReturnsFalseForMermaidGraphTD() {
        let d2 = D2Importer()
        #expect(!d2.supports(source: "graph TD\nA-->B"))
    }

    @Test("supports returns false for Mermaid flowchart source")
    func supportsReturnsFalseForMermaidFlowchart() {
        let d2 = D2Importer()
        #expect(!d2.supports(source: "flowchart LR\nA-->B"))
    }

    @Test("supports returns false for DOT digraph source")
    func supportsReturnsFalseForDOTDigraph() {
        let d2 = D2Importer()
        #expect(!d2.supports(source: "digraph G {\n  a -> b\n}"))
    }

    @Test("supports returns false for PlantUML source")
    func supportsReturnsFalseForPlantUML() {
        let d2 = D2Importer()
        #expect(!d2.supports(source: "@startuml\nAlice -> Bob: Hello\n@enduml"))
    }

    @Test("supports returns false for Structurizr source")
    func supportsReturnsFalseForStructurizr() {
        let d2 = D2Importer()
        #expect(!d2.supports(source: "workspace {\n  model {\n    user = person\n  }\n}"))
    }

    // MARK: - Basic properties

    @Test("supportedDiagramTypes covers flowchart, classDiagram, stateDiagram, erDiagram")
    func supportedDiagramTypesIsFlowchart() {
        let d2 = D2Importer()
        #expect(d2.supportedDiagramTypes == [.flowchart, .classDiagram, .stateDiagram, .erDiagram])
    }

    @Test("name is \"D2\"")
    func nameIsD2() {
        let d2 = D2Importer()
        #expect(d2.name == "D2")
    }

    // MARK: - parse

    @Test("parse returns flowchart DiagramDocument")
    func parseReturnsFlowchartDocument() throws {
        let d2 = D2Importer()
        let result = try d2.parse("A -> B")
        #expect(result.document.type == .flowchart)
    }

    @Test("parse returns node with correct label")
    func parseReturnsNodeWithCorrectLabel() throws {
        let d2 = D2Importer()
        let result = try d2.parse("A: Start")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.nodesInOrder.count == 1)
        #expect(graph.nodesInOrder[0].id == "A")
        #expect(graph.nodesInOrder[0].node.label == "Start")
    }

    @Test("parse returns edge with correct source/target")
    func parseReturnsEdgeWithCorrectSourceTarget() throws {
        let d2 = D2Importer()
        let result = try d2.parse("A -> B")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.edges.count == 1)
        #expect(graph.edges[0].source == "A")
        #expect(graph.edges[0].target == "B")
    }

    @Test("parse synthesizes nodes for edge-only endpoints")
    func parseSynthesizesNodesForEdgeOnlyEndpoints() throws {
        let d2 = D2Importer()
        let result = try d2.parse("A -> B")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.nodesInOrder.map(\.id) == ["A", "B"])
        #expect(graph.nodesInOrder.map(\.node.label) == ["A", "B"])
    }

    @Test("parse maps shape: cylinder to .cylinder")
    func parseMapsShapeCylinder() throws {
        let d2 = D2Importer()
        let result = try d2.parse("A.shape: cylinder")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.nodesInOrder.count >= 1)
        #expect(graph.nodesInOrder[0].node.shape == .cylinder)
    }

    @Test("parse merges node labels and property statements")
    func parseMergesNodeLabelsAndPropertyStatements() throws {
        let d2 = D2Importer()
        let result = try d2.parse("A: Database\nA.shape: cylinder")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.nodesInOrder.count == 1)
        #expect(graph.nodesInOrder[0].id == "A")
        #expect(graph.nodesInOrder[0].node.label == "Database")
        #expect(graph.nodesInOrder[0].node.shape == .cylinder)
    }

    @Test("parse maps direction: right to .LR")
    func parseMapsDirectionRight() throws {
        let d2 = D2Importer()
        let result = try d2.parse("direction: right\nA -> B")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.direction == .LR)
    }

    @Test("parse does not render top-level direction as a node")
    func parseDoesNotRenderTopLevelDirectionAsNode() throws {
        let d2 = D2Importer()
        let result = try d2.parse("direction: right\nA -> B")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.direction == .LR)
        #expect(!graph.nodesInOrder.map(\.id).contains("direction"))
        #expect(graph.nodesInOrder.map(\.id) == ["A", "B"])
    }

    @Test("parse assigns edge-only endpoints to containing subgraph")
    func parseAssignsEdgeOnlyEndpointsToContainingSubgraph() throws {
        let d2 = D2Importer()
        let result = try d2.parse("Group {\n  A -> B\n}")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        let subgraph = try #require(graph.subgraphs.first)
        #expect(graph.nodesInOrder.map(\.id) == ["A", "B"])
        #expect(subgraph.nodeIds == ["A", "B"])
    }

    @Test("parse maps A <-> B to bidirectional arrowheads")
    func parseMapsBidirectionalArrowheads() throws {
        let d2 = D2Importer()
        let result = try d2.parse("A <-> B")
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(graph.edges.count == 1)
        #expect(graph.edges[0].arrowHeadStart == .arrow)
        #expect(graph.edges[0].arrowHeadEnd == .arrow)
    }

    // MARK: - Diagnostics

    @Test("parse emits diagnostic for unsupported shape: sql_table")
    func parseEmitsDiagnosticForSqlTableShape() throws {
        let d2 = D2Importer()
        let result = try d2.parse("A.shape: sql_table")
        #expect(result.diagnostics.count >= 1)
        #expect(result.diagnostics.contains(where: { $0.message.contains("sql_table") }))
    }

    @Test("parse emits diagnostic for style.* keywords")
    func parseEmitsDiagnosticForStyleKeyword() throws {
        let d2 = D2Importer()
        let result = try d2.parse("style.fill: red")
        #expect(result.diagnostics.count >= 1)
        #expect(result.diagnostics.contains(where: { $0.message.contains("style") }))
    }

    @Test("parse emits diagnostic for layers.* keywords")
    func parseEmitsDiagnosticForLayersKeyword() throws {
        let d2 = D2Importer()
        let result = try d2.parse("layers.a: 1")
        #expect(result.diagnostics.count >= 1)
        #expect(result.diagnostics.contains(where: { $0.message.contains("layers") }))
    }

    // MARK: - Layout smoke

    @Test("d2 source parses through layout without crashing")
    func d2SourceLayoutSmoke() throws {
        let d2Source = "direction: right\nA: Start\nB: End\nA -> B"
        let importer = D2Importer()
        let result = try importer.parse(d2Source)
        #expect(result.document.type == .flowchart)

        let positioned = try DiagramPipeline.layout(result.document)
        _ = positioned
        #expect(!(positioned.flowchartNodes?.isEmpty ?? true))
    }
}
