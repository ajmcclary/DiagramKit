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
        #expect(exporter.supportedDiagramTypes.contains(.classDiagram))
        #expect(!exporter.supportedDiagramTypes.contains(.c4))
    }

    @Test("PlantUML class export emits @startuml/@enduml with members")
    func classExportBasic() throws {
        let attr = ClassMember(id: "name", visibility: "+", memberType: .attribute, returnType: "String")
        let method = ClassMember(id: "greet", visibility: "+", memberType: .method, returnType: "Void")
        let node = ClassNode(id: "Person", label: "Person", attributes: [attr], methods: [method])
        let model = ClassDiagram(classes: [node], classMap: ["Person": node])

        let result = try PlantUMLExporter().export(DiagramDocument(payload: .classDiagram(model)))
        #expect(result.source.contains("@startuml"))
        #expect(result.source.contains("@enduml"))
        #expect(result.source.contains("class Person {"))
        #expect(result.source.contains("+name: String"))
        #expect(result.source.contains("+greet(): Void"))
    }

    @Test("PlantUML gantt export round-trips through PlantUMLImporter")
    func ganttExportRoundTrip() throws {
        let source = """
        @startgantt
        project starts 2024-01-15
        [Design] lasts 10 days
        [Build] lasts 20 days
        @endgantt
        """
        let parsed = try PlantUMLImporter().parse(source).document
        let exported = try PlantUMLExporter().export(parsed)
        #expect(exported.source.contains("@startgantt"))
        #expect(exported.source.contains("@endgantt"))
        #expect(exported.source.contains("[Design]"))
        #expect(exported.source.contains("[Build]"))
        let reparsed = try PlantUMLImporter().parse(exported.source).document
        guard case .gantt(let model) = reparsed.payload else {
            Issue.record("Expected gantt payload"); return
        }
        #expect(model.tasks.count == 2)
        #expect(model.tasks.first(where: { $0.task == "Design" }) != nil)
        #expect(model.tasks.first(where: { $0.task == "Build" }) != nil)
    }

    @Test("PlantUML mindmap export round-trips through PlantUMLImporter")
    func mindmapExportRoundTrip() throws {
        let source = """
        @startmindmap
        * Root
        ** Child A
        *** Grandchild A1
        ** Child B
        @endmindmap
        """
        let parsed = try PlantUMLImporter().parse(source).document
        let exported = try PlantUMLExporter().export(parsed)
        #expect(exported.source.contains("@startmindmap"))
        #expect(exported.source.contains("@endmindmap"))
        #expect(exported.source.contains("* Root"))
        #expect(exported.source.contains("** Child A"))
        #expect(exported.source.contains("*** Grandchild A1"))
        let reparsed = try PlantUMLImporter().parse(exported.source).document
        guard case .mindmap(let model) = reparsed.payload else {
            Issue.record("Expected mindmap payload"); return
        }
        #expect(model.root?.descr == "Root")
        #expect(model.root?.children.count == 2)
    }

    @Test("PlantUML state export round-trips through PlantUMLImporter")
    func stateExportRoundTrip() throws {
        let source = """
        @startuml
        [*] --> Idle
        Idle --> Working : start
        Working --> [*]
        @enduml
        """
        let parsed = try PlantUMLImporter().parse(source).document
        let exported = try PlantUMLExporter().export(parsed)
        #expect(exported.source.contains("@startuml"))
        #expect(exported.source.contains("[*] -->"))
        #expect(exported.source.contains("--> [*]"))
        // Re-import and confirm Idle/Working survive
        let reparsed = try PlantUMLImporter().parse(exported.source).document
        guard case .stateDiagram(let graph) = reparsed.payload else {
            Issue.record("Expected stateDiagram payload"); return
        }
        let nodeIds = Set(graph.nodesInOrder.map(\.id))
        #expect(nodeIds.contains("Idle"))
        #expect(nodeIds.contains("Working"))
    }

    @Test("PlantUML class export round-trips through PlantUMLImporter")
    func classExportRoundTrip() throws {
        let attr = ClassMember(id: "name", visibility: "+", memberType: .attribute, returnType: "String")
        let method = ClassMember(id: "greet", visibility: "+", memberType: .method, returnType: "Void")
        let person = ClassNode(id: "Person", label: "Person", attributes: [attr], methods: [method])
        let pet = ClassNode(id: "Pet", label: "Pet", annotations: ["Interface"])

        let inheritance = ClassRelationship(
            id1: "Animal",
            id2: "Person",
            relation: ClassRelationEndpoint(
                type1: ClassRelationType.inheritance.rawValue,
                type2: ClassRelationType.none.rawValue,
                lineType: ClassLineType.solid.rawValue
            )
        )
        let model = ClassDiagram(
            classes: [
                ClassNode(id: "Animal", label: "Animal"),
                person,
                pet
            ],
            relationships: [inheritance]
        )

        let exported = try PlantUMLExporter().export(DiagramDocument(payload: .classDiagram(model)))
        let reparsed = try PlantUMLImporter().parse(exported.source).document
        guard case .classDiagram(let model2) = reparsed.payload else {
            Issue.record("Expected classDiagram payload after round-trip, got \(reparsed.payload)")
            return
        }
        #expect(model2.classes.contains(where: { $0.id == "Person" }))
        #expect(model2.classes.contains(where: { $0.id == "Animal" }))
        #expect(model2.classes.first(where: { $0.id == "Pet" })?.annotations.contains("Interface") == true)
        let rel = model2.relationships.first { $0.id1 == "Animal" && $0.id2 == "Person" }
        #expect(rel?.relation.type1 == ClassRelationType.inheritance.rawValue)
        #expect(rel?.relation.lineType == ClassLineType.solid.rawValue)
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
