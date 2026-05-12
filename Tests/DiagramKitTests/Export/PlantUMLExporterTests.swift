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
        #expect(exporter.supportedDiagramTypes.contains(.c4))
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

    @Test("PlantUML export unsupported type returns diagnostic")
    func unsupportedType() throws {
        let doc = DiagramDocument(type: .flowchart)
        let result = try PlantUMLExporter().export(doc)
        #expect(result.source.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .unsupported })
    }

    @Test("PlantUML C4 export includes !include")
    func c4Export() throws {
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

        #expect(result.source.contains("@startuml"))
        #expect(result.source.contains("!include"))
        #expect(result.source.contains("Person(customer"))
        #expect(result.source.contains("System(system"))
        #expect(result.source.contains("Rel(customer"))
        #expect(result.source.contains("@enduml"))
    }
}
