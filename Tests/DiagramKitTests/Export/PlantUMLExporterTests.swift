import Testing
import DiagramKitModel
import DiagramKitPlantUML

@Suite struct PlantUMLExporterTests {

    @Test("PlantUML exporter has correct name and format ID")
    func identity() {
        let exporter = PlantUMLExporter()
        #expect(exporter.name == "PlantUML")
        #expect(exporter.formatID == .plantuml)
        #expect(exporter.supportedDiagramTypes.contains(.sequenceDiagram))
        #expect(!exporter.supportedDiagramTypes.contains(.c4))
    }

    @Test("PlantUML sequence export produces @startuml/@enduml")
    func sequenceExport() throws {
        let seq = SequenceDiagram(items: [
            .actor(SequenceActor(id: "Alice", label: "Alice", type: .participant)),
            .actor(SequenceActor(id: "Bob", label: "Bob", type: .participant)),
            .message(SequenceMessage(from: "Alice", to: "Bob", label: "Hello", arrowType: .solid))
        ])
        let doc = DiagramDocument(payload: .sequenceDiagram(seq))
        let result = try PlantUMLExporter().export(doc)

        #expect(result.source.contains("@startuml"))
        #expect(result.source.contains("@enduml"))
        #expect(result.source.contains("participant Alice"))
        #expect(result.source.contains("Alice -> Bob"))
    }

    @Test("PlantUML sequence aliases and notes round-trip through importer")
    func sequenceAliasAndNoteRoundTrip() throws {
        let seq = SequenceDiagram(items: [
            .actor(SequenceActor(id: "alice", label: "Alice Adams", type: .participant)),
            .actor(SequenceActor(id: "bob", label: "Bob Brown", type: .participant)),
            .message(SequenceMessage(from: "alice", to: "bob", label: "Hello", arrowType: .solid)),
            .note(SequenceNote(actorIds: ["bob"], text: "note text", position: "right"))
        ])

        let result = try PlantUMLExporter().export(DiagramDocument(payload: .sequenceDiagram(seq)))
        #expect(result.source.contains("participant \"Alice Adams\" as alice"))
        #expect(result.source.contains("participant \"Bob Brown\" as bob"))
        #expect(result.source.contains("note right of bob: note text"))

        let reparsed = try PlantUMLImporter().parse(result.source).document
        guard case .sequenceDiagram(let reparsedSequence) = reparsed.payload else {
            Issue.record("Expected sequence payload")
            return
        }
        #expect(reparsedSequence.actors.first(where: { $0.id == "alice" })?.label == "Alice Adams")
        #expect(reparsedSequence.actors.first(where: { $0.id == "bob" })?.label == "Bob Brown")
        #expect(reparsedSequence.messages.first?.from == "alice")
        #expect(reparsedSequence.messages.first?.to == "bob")
        #expect(reparsedSequence.notes.first?.position == "right")
        #expect(reparsedSequence.notes.first?.text == "note text")
    }

    @Test("PlantUML export unsupported type returns diagnostic")
    func unsupportedType() throws {
        let doc = DiagramDocument(type: .flowchart)
        let result = try PlantUMLExporter().export(doc)
        #expect(result.source.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .unsupported })
    }

    @Test("PlantUML C4 export is gated until the PlantUML C4 importer exists")
    func c4ExportIsUnsupported() throws {
        let c4 = C4Diagram(
            kind: .context,
            shapes: [
                C4Shape(alias: "customer", label: "Customer", typeC4Shape: .person),
                C4Shape(alias: "system", label: "System", typeC4Shape: .system)
            ],
            relationships: [
                C4Relationship(kind: .rel, from: "customer", to: "system", label: "Uses")
            ]
        )
        let doc = DiagramDocument(payload: .c4(c4))
        let result = try PlantUMLExporter().export(doc)

        #expect(result.source.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .unsupported })
    }
}
