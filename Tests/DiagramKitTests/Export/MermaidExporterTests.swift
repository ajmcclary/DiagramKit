import Testing
import DiagramKitModel
import DiagramKitMermaid
// `MermaidImporter` still lives in the umbrella; the umbrella import here
// proves the exporter is constructible from `DiagramKitMermaid` while the
// importer side keeps round-trip tests pointed at the same parser.
import DiagramKit

@Suite struct MermaidExporterTests {

    // MARK: - Supported types

    @Test("MermaidExporter supports P0 diagram types")
    func supportedTypes() {
        let exporter = MermaidExporter()
        #expect(exporter.name == "Mermaid")
        #expect(exporter.formatID == .mermaid)
        #expect(exporter.supportedDiagramTypes.contains(.flowchart))
        #expect(exporter.supportedDiagramTypes.contains(.sequenceDiagram))
        #expect(exporter.supportedDiagramTypes.contains(.classDiagram))
        #expect(exporter.supportedDiagramTypes.contains(.erDiagram))
        #expect(exporter.supportedDiagramTypes.contains(.c4))
    }

    // MARK: - Full family coverage

    // The exporter went 28/28 in 3f0880ae ("Close Mermaid exporter
    // completion"); there is no unsupported family left. Pin that.
    @Test("MermaidExporter supports every diagram family")
    func fullFamilyCoverage() throws {
        let exporter = MermaidExporter()
        for family in DiagramType.allCases {
            #expect(
                exporter.supportedDiagramTypes.contains(family),
                "family \(family.rawValue) missing from supportedDiagramTypes"
            )
        }
        // Formerly-pending mindmap now exports real source.
        let result = try exporter.export(DiagramDocument(type: .mindmap))
        #expect(!result.source.isEmpty)
    }

    // MARK: - Flowchart

    @Test("Flowchart export produces valid Mermaid source")
    func flowchartExportBasic() throws {
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "Start", shape: .rectangle)),
                (id: "B", node: original_src_types.MermaidNode(id: "B", label: "End", shape: .rectangle))
            ],
            edges: [
                original_src_types.MermaidEdge(source: "A", target: "B", label: "goes to", style: .solid)
            ]
        )
        let doc = DiagramDocument(payload: .flowchart(graph))
        let result = try MermaidExporter().export(doc)

        #expect(result.source.contains("graph TD"))
        #expect(result.source.contains("A[Start]"))
        #expect(result.source.contains("B[End]"))
        #expect(result.source.contains("-->"))
    }

    @Test("Flowchart edge labels are emitted in parser-compatible Mermaid syntax")
    func flowchartEdgeLabelRoundTrips() throws {
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "Start", shape: .rectangle)),
                (id: "B", node: original_src_types.MermaidNode(id: "B", label: "End", shape: .rectangle))
            ],
            edges: [
                original_src_types.MermaidEdge(source: "A", target: "B", label: "goes to", style: .solid)
            ]
        )

        let result = try MermaidExporter().export(DiagramDocument(payload: .flowchart(graph)))
        #expect(result.source.contains("A -- goes to --> B"))

        let reparsed = try MermaidImporter().parse(result.source).document
        guard case .flowchart(let reparsedGraph) = reparsed.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(reparsedGraph.edges.first?.label == "goes to")
    }

    @Test("Flowchart export empty graph produces minimum valid source")
    func flowchartEmptyGraph() throws {
        let doc = DiagramDocument(type: .flowchart)
        let result = try MermaidExporter().export(doc)
        #expect(!result.source.isEmpty)
        #expect(result.source.contains("graph"))
    }

    // MARK: - Sequence

    @Test("Sequence export produces valid Mermaid source")
    func sequenceExportBasic() throws {
        let seq = SequenceDiagram(items: [
            .actor(SequenceActor(id: "Alice", label: "Alice", type: .participant)),
            .actor(SequenceActor(id: "Bob", label: "Bob", type: .participant)),
            .message(SequenceMessage(from: "Alice", to: "Bob", label: "Hello", arrowType: .solid))
        ])
        let doc = DiagramDocument(payload: .sequenceDiagram(seq))
        let result = try MermaidExporter().export(doc)

        #expect(result.source.contains("sequenceDiagram"))
        #expect(result.source.contains("participant"))
        #expect(result.source.contains("Alice"))
        #expect(result.source.contains("Bob"))
    }

    @Test("Sequence messages and left/right notes round-trip through Mermaid source")
    func sequenceMessageAndNoteRoundTrip() throws {
        let seq = SequenceDiagram(items: [
            .actor(SequenceActor(id: "Alice", label: "Alice", type: .participant)),
            .actor(SequenceActor(id: "Bob", label: "Bob", type: .participant)),
            .message(SequenceMessage(from: "Alice", to: "Bob", label: "status: ok", arrowType: .solid)),
            .note(SequenceNote(actorIds: ["Bob"], text: "observe: carefully", position: "right"))
        ])

        let result = try MermaidExporter().export(DiagramDocument(payload: .sequenceDiagram(seq)))
        #expect(result.source.contains("Alice->>Bob: status: ok"))
        #expect(result.source.contains("Note right of Bob: observe: carefully"))

        let reparsed = try MermaidImporter().parse(result.source).document
        guard case .sequenceDiagram(let reparsedSequence) = reparsed.payload else {
            Issue.record("Expected sequence payload")
            return
        }
        #expect(reparsedSequence.messages.first?.label == "status: ok")
        #expect(reparsedSequence.notes.first?.position == "right")
        #expect(reparsedSequence.notes.first?.text == "observe: carefully")
    }

    // MARK: - Class

    @Test("Class export produces valid Mermaid source")
    func classExportBasic() throws {
        let cls = ClassDiagram(
            classes: [ClassNode(id: "Animal", label: "Animal")],
            direction: .TB
        )
        let doc = DiagramDocument(payload: .classDiagram(cls))
        let result = try MermaidExporter().export(doc)

        #expect(result.source.contains("classDiagram"))
        #expect(result.source.contains("Animal"))
    }

    // MARK: - ER

    @Test("ER export produces valid Mermaid source")
    func erExportBasic() throws {
        let er = ErDiagram(
            entities: [
                ErEntity(key: "CUSTOMER", label: "Customer"),
                ErEntity(key: "ORDER", label: "Order")
            ],
            relationships: [
                ErRelationship(
                    entity1: "CUSTOMER", entity2: "ORDER",
                    entityAId: "entity-CUSTOMER-1", entityBId: "entity-ORDER-2",
                    roleA: "places",
                    relSpec: ErRelSpec(cardA: .onlyOne, cardB: .zeroOrMore, relType: .identifying)
                )
            ]
        )
        let doc = DiagramDocument(payload: .erDiagram(er))
        let result = try MermaidExporter().export(doc)

        #expect(result.source.contains("erDiagram"))
        #expect(result.source.contains("CUSTOMER"))
        #expect(result.source.contains("ORDER"))
        #expect(result.source.contains("places"))
    }

    // MARK: - C4

    @Test("C4 export produces valid Mermaid source")
    func c4ExportBasic() throws {
        let c4 = C4Diagram(
            kind: .context,
            shapes: [
                C4Shape(alias: "customer", label: "Customer", typeC4Shape: .person),
                C4Shape(alias: "system", label: "System", typeC4Shape: .system, description: "A system")
            ],
            relationships: [
                C4Relationship(kind: .rel, from: "customer", to: "system", label: "Uses")
            ]
        )
        let doc = DiagramDocument(payload: .c4(c4))
        let result = try MermaidExporter().export(doc)

        #expect(result.source.contains("C4Context"))
        #expect(result.source.contains("Person(customer"))
        #expect(result.source.contains("System(system"))
        #expect(result.source.contains("Rel(customer, system"))
    }
}
