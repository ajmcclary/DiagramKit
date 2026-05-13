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

    // MARK: - Review Critical 8: newline normalization in sequence escape

    @Test("PlantUML sequence export normalizes newlines in title, note, group, box, and else labels")
    func sequenceEscapeNormalizesNewlines() throws {
        let seq = SequenceDiagram(items: [
            .title("Line one\nLine two\r\nLine three\rLine four"),
            .actor(SequenceActor(id: "alice", label: "Alice", type: .participant)),
            .actor(SequenceActor(id: "bob", label: "Bob", type: .participant)),
            .boxStart(fill: "#EEE", title: "Box A\nB", wrap: false),
            .message(SequenceMessage(from: "alice", to: "bob", label: "Hello", arrowType: .solid)),
            .boxEnd,
            .blockStart(type: "alt", label: "First\nsecond"),
            .message(SequenceMessage(from: "alice", to: "bob", label: "case A", arrowType: .solid)),
            .blockDivider(type: "alt", label: "else\nbranch"),
            .message(SequenceMessage(from: "alice", to: "bob", label: "case B", arrowType: .solid)),
            .blockEnd(type: "alt"),
            .note(SequenceNote(actorIds: ["bob"], text: "first line\nsecond line", position: "right"))
        ])
        let result = try PlantUMLExporter().export(DiagramDocument(payload: .sequenceDiagram(seq)))

        // The escape helper must convert all newline variants into PlantUML's
        // inline-newline escape `\n` so no label produces a second line in the
        // @startuml/@enduml body.
        let bodyLines = result.source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for line in bodyLines {
            #expect(!line.contains("\r"), "Raw carriage return leaked through escape: \(line)")
        }
        #expect(result.source.contains("title Line one\\nLine two\\nLine three\\nLine four"))
        #expect(result.source.contains("alt First\\nsecond"))
        #expect(result.source.contains("else else\\nbranch"))
        #expect(result.source.contains("note right of bob: first line\\nsecond line"))
        #expect(result.source.contains("box \"Box A\\nB\""))
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
