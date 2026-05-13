import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
import DiagramKitGraphviz
import DiagramKit

@Suite struct DOTExporterTests {

    @Test("DOT exporter has correct name and format ID")
    func identity() {
        let exporter = DOTExporter()
        #expect(exporter.name == "Graphviz")
        #expect(exporter.formatID == .graphviz)
        #expect(exporter.supportedDiagramTypes.contains(.flowchart))
        #expect(!exporter.supportedDiagramTypes.contains(.sequenceDiagram))
    }

    @Test("DOT flowchart export produces valid DOT source")
    func flowchartExport() throws {
        let graph = ParsedGraphModel(
            direction: .LR,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "Start", shape: .rectangle)),
                (id: "B", node: original_src_types.MermaidNode(id: "B", label: "End", shape: .rectangle))
            ],
            edges: [
                original_src_types.MermaidEdge(source: "A", target: "B", label: "go", style: .solid)
            ]
        )
        let doc = DiagramDocument(payload: .flowchart(graph))
        let result = try DOTExporter().export(doc)

        #expect(result.source.contains("digraph G {"))
        #expect(result.source.contains("rankdir=LR;"))
        #expect(result.source.contains("A [label=\"Start\""))
        #expect(result.source.contains("A -> B [label=\"go\"];"))
        #expect(result.source.hasSuffix("}"))
    }

    @Test("DOT exporter quotes non-bareword identifiers")
    func quotesNonBarewordIds() throws {
        let graph = ParsedGraphModel(
            direction: .TB,
            nodesInOrder: [
                (id: "node 1", node: original_src_types.MermaidNode(id: "node 1", label: "One", shape: .rectangle)),
                (id: "B", node: original_src_types.MermaidNode(id: "B", label: "Two", shape: .rectangle))
            ],
            edges: [
                original_src_types.MermaidEdge(source: "node 1", target: "B", label: nil, style: .solid)
            ]
        )
        let result = try DOTExporter().export(DiagramDocument(payload: .flowchart(graph)))

        #expect(result.source.contains("\"node 1\" [label=\"One\""))
        #expect(result.source.contains("\"node 1\" -> B;"))
    }

    @Test("DOT export unsupported type returns diagnostic")
    func unsupportedType() throws {
        let doc = DiagramDocument(type: .sequenceDiagram)
        let result = try DOTExporter().export(doc)
        #expect(result.source.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .unsupported })
    }

    @Test("DOT export escapes quotes and backslashes in labels")
    func escapesQuotedLabels() throws {
        let graph = ParsedGraphModel(
            direction: .LR,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: #"Say "hi"\again"#, shape: .rectangle))
            ],
            edges: []
        )
        let result = try DOTExporter().export(DiagramDocument(payload: .flowchart(graph)))
        #expect(result.source.contains(#"label="Say \"hi\"\\again""#))
    }

    @Test("DOT export round-trips through GraphvizImporter")
    func roundTripsThroughImporter() throws {
        let graph = ParsedGraphModel(
            direction: .LR,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "Start", shape: .rectangle)),
                (id: "B", node: original_src_types.MermaidNode(id: "B", label: "End", shape: .rectangle))
            ],
            edges: [
                original_src_types.MermaidEdge(source: "A", target: "B", label: "go", style: .solid)
            ]
        )
        let result = try DOTExporter().export(DiagramDocument(payload: .flowchart(graph)))

        let reparsed = try GraphvizImporter().parse(result.source).document
        guard case .flowchart(let reparsedGraph) = reparsed.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(reparsedGraph.nodesInOrder.map(\.id) == ["A", "B"])
        #expect(reparsedGraph.edges.count == 1)
        #expect(reparsedGraph.edges.first?.source == "A")
        #expect(reparsedGraph.edges.first?.target == "B")
        #expect(reparsedGraph.edges.first?.label == "go")
    }
}
