import Testing
import DiagramKitModel
import DiagramKitStructurizr

@Suite struct StructurizrExporterTests {

    @Test("Structurizr exporter has correct name and format ID")
    func identity() {
        let exporter = StructurizrExporter()
        #expect(exporter.name == "Structurizr")
        #expect(exporter.formatID == .structurizr)
        #expect(exporter.supportedDiagramTypes.contains(.c4))
        #expect(!exporter.supportedDiagramTypes.contains(.flowchart))
    }

    @Test("Structurizr C4 export produces valid workspace source")
    func c4Export() throws {
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
        let result = try StructurizrExporter().export(doc)

        #expect(result.source.contains("workspace {"))
        #expect(result.source.contains("model {"))
        #expect(result.source.contains("views {"))
        #expect(result.source.contains("customer = person"))
        #expect(result.source.contains("system = softwareSystem"))
    }

    @Test("Structurizr C4 export escapes quoted strings for parser-compatible source")
    func c4ExportEscapesQuotedStrings() throws {
        let c4 = C4Diagram(
            kind: .context,
            shapes: [
                C4Shape(alias: "customer", label: #"Customer "A"\B"#, typeC4Shape: .person),
                C4Shape(alias: "system", label: "System", typeC4Shape: .system, description: #"Line "one"\two"#)
            ],
            relationships: [
                C4Relationship(kind: .rel, from: "customer", to: "system", label: #"Uses "API"\v1"#)
            ]
        )

        let result = try StructurizrExporter().export(DiagramDocument(payload: .c4(c4)))
        #expect(result.source.contains(#"customer = person "Customer \"A\"\\B""#))
        #expect(result.source.contains(#"system = softwareSystem "System" "Line \"one\"\\two""#))
        #expect(result.source.contains(#"customer -> system "Uses \"API\"\\v1""#))

        let reparsed = try StructurizrImporter().parse(result.source).document
        guard case .c4(let reparsedC4) = reparsed.payload else {
            Issue.record("Expected C4 payload")
            return
        }
        #expect(reparsedC4.shapes.first(where: { $0.alias == "customer" })?.label == #"Customer "A"\B"#)
        #expect(reparsedC4.shapes.first(where: { $0.alias == "system" })?.description == #"Line "one"\two"#)
        #expect(reparsedC4.relationships.first?.label == #"Uses "API"\v1"#)
    }

    @Test("Structurizr export unsupported type returns diagnostic")
    func unsupportedType() throws {
        let doc = DiagramDocument(type: .flowchart)
        let result = try StructurizrExporter().export(doc)
        #expect(result.source.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .unsupported })
    }
}
