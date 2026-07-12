import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitD2

@Suite struct D2ExporterTests {

    @Test("D2 exporter has correct name and format ID")
    func identity() {
        let exporter = D2Exporter()
        #expect(exporter.name == "D2")
        #expect(exporter.formatID == .d2)
        #expect(exporter.supportedDiagramTypes.contains(.flowchart))
        #expect(exporter.supportedDiagramTypes.contains(.sequenceDiagram))
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

    @Test("D2 export preserves DiagramDocument title as importable metadata")
    func flowchartExportTitleRoundTrips() throws {
        let graph = ParsedGraphModel(
            direction: .LR,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "Hello", shape: .rectangle))
            ],
            edges: []
        )
        var doc = DiagramDocument(payload: .flowchart(graph))
        doc.title = "D2 Title"

        let result = try D2Exporter().export(doc)
        #expect(result.source.hasPrefix("# title: D2 Title\n"))

        let reparsed = try D2Importer().parse(result.source).document
        #expect(reparsed.title == "D2 Title")
    }

    @Test("D2 export unsupported type returns diagnostic")
    func unsupportedType() throws {
        let doc = DiagramDocument(type: .gantt)
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

    @Test("D2 flowchart with subgraph surfaces a .warning diagnostic (drop disclosure)")
    func subgraphProducesWarning() throws {
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "A", shape: .rectangle)),
                (id: "B", node: original_src_types.MermaidNode(id: "B", label: "B", shape: .rectangle))
            ],
            edges: [original_src_types.MermaidEdge(source: "A", target: "B", style: .solid)],
            subgraphs: [
                original_src_types.MermaidSubgraph(
                    id: "cluster1",
                    label: "Cluster One",
                    nodeIds: ["A", "B"]
                )
            ]
        )
        let result = try D2Exporter().export(DiagramDocument(payload: .flowchart(graph)))
        #expect(result.diagnostics.contains { $0.severity == .warning && $0.message.contains("cluster1") })
    }

    @Test(
        "D2 flowchart shape downgrade emits paired .shapeDowngrade diagnostic",
        arguments: [
            original_src_types.NodeShape.rounded,
            .doublecircle,
            .smallCircle,
            .framedCircle,
            .filledCircle,
            .crossedCircle,
            .horizontalCylinder,
            .linedCylinder,
            .parallelogramAlt,
            .trapezoid,
            .trapezoidAlt,
            .subroutine,
        ]
    )
    func lossyShapeEmitsDiagnostic(shape: original_src_types.NodeShape) throws {
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [
                (id: "n", node: original_src_types.MermaidNode(id: "n", label: "x", shape: shape))
            ],
            edges: []
        )
        let result = try D2Exporter().export(DiagramDocument(payload: .flowchart(graph)))
        let shapeDiags = result.diagnostics.filter { $0.category == .shapeDowngrade && $0.severity == .warning }
        #expect(shapeDiags.count == 1)
        #expect(shapeDiags.first?.message.contains("'n'") == true)
        #expect(shapeDiags.first?.message.contains(shape.rawValue) == true)
    }

    @Test("D2 flowchart lossless shapes emit no shape diagnostic")
    func losslessShapesEmitNoDiagnostic() throws {
        let lossless: [original_src_types.NodeShape] = [
            .rectangle, .diamond, .circle, .hexagon, .cylinder, .stadium, .parallelogram,
        ]
        for shape in lossless {
            let graph = ParsedGraphModel(
                direction: .TD,
                nodesInOrder: [
                    (id: "n", node: original_src_types.MermaidNode(id: "n", label: "x", shape: shape))
                ],
                edges: []
            )
            let result = try D2Exporter().export(DiagramDocument(payload: .flowchart(graph)))
            #expect(!result.diagnostics.contains { $0.category == .shapeDowngrade })
        }
    }
}
