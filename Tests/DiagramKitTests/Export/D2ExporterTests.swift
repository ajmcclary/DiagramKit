import Testing
import DiagramKitModel
import DiagramKitD2

@Suite struct D2ExporterTests {

    @Test("D2 exporter has correct name and format ID")
    func identity() {
        let exporter = D2Exporter()
        #expect(exporter.name == "D2")
        #expect(exporter.formatID == .d2)
        #expect(exporter.supportedDiagramTypes.contains(.flowchart))
        #expect(!exporter.supportedDiagramTypes.contains(.sequenceDiagram))
    }

    @Test("D2 flowchart export produces valid D2 source")
    func flowchartExport() throws {
        let graph = ParsedGraphModel(
            direction: .LR,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "Hello", shape: .rectangle)),
                (id: "B", node: original_src_types.MermaidNode(id: "B", label: "World", shape: .rectangle))
            ],
            edges: [
                original_src_types.MermaidEdge(source: "A", target: "B", label: "to", style: .solid)
            ]
        )
        let doc = DiagramDocument(payload: .flowchart(graph))
        let result = try D2Exporter().export(doc)

        #expect(result.source.contains("direction: right"))
        #expect(result.source.contains("A:"))
        #expect(result.source.contains("B:"))
        #expect(result.source.contains("->"))
    }

    @Test("D2 flowchart export escapes quoted labels for parser-compatible source")
    func flowchartExportEscapesQuotedLabels() throws {
        let graph = ParsedGraphModel(
            direction: .LR,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: #"Say "hello"\again"#, shape: .rectangle)),
                (id: "B", node: original_src_types.MermaidNode(id: "B", label: "World", shape: .rectangle))
            ],
            edges: [
                original_src_types.MermaidEdge(source: "A", target: "B", label: #"use "edge"\path"#, style: .solid)
            ]
        )

        let result = try D2Exporter().export(DiagramDocument(payload: .flowchart(graph)))
        #expect(result.source.contains(#"A: "Say \"hello\"\\again""#))
        #expect(result.source.contains(#"A -> B: "use \"edge\"\\path""#))

        let reparsed = try D2Importer().parse(result.source).document
        guard case .flowchart(let reparsedGraph) = reparsed.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(reparsedGraph.nodesInOrder.first(where: { $0.id == "A" })?.node.label == #"Say "hello"\again"#)
        #expect(reparsedGraph.edges.first?.label == #"use "edge"\path"#)
    }

    @Test("D2 export unsupported type returns diagnostic")
    func unsupportedType() throws {
        let doc = DiagramDocument(type: .sequenceDiagram)
        let result = try D2Exporter().export(doc)
        #expect(result.source.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .unsupported })
    }

    @Test("D2 empty flowchart produces valid source")
    func emptyFlowchart() throws {
        let doc = DiagramDocument(type: .flowchart)
        let result = try D2Exporter().export(doc)
        #expect(!result.source.isEmpty)
        #expect(result.source.contains("direction:"))
    }
}
