import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel
import DiagramKitTestSupport
@testable import DiagramKitPlantUML

@Suite("PlantUMLObjectRoundTripTests")
struct PlantUMLObjectRoundTripTests {

    @Test func basicObjectParsesToClassDiagram() throws {
        let source = """
        @startuml
        object alice {
          name = "Alice"
          age = 30
        }
        object bob {
          name = "Bob"
          age = 25
        }
        alice --> bob : friend_of
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .classDiagram(let cd) = result.document.payload else {
            Issue.record("Expected classDiagram payload, got \(result.document.payload)"); return
        }
        #expect(cd.classes.count == 2)
        #expect(cd.classes[0].id == "alice")
        #expect(cd.classes[1].id == "bob")
        #expect(cd.classes[0].attributes.count == 2)
        #expect(cd.relationships.count == 1)
        #expect(cd.relationships[0].id1 == "alice")
        #expect(cd.relationships[0].id2 == "bob")
        let shapeDiagnostics = result.diagnostics.filter { $0.category == .shapeDowngrade }
        #expect(shapeDiagnostics.count == 2)
    }

    @Test func basicObjectRoundTripsViaWrapper() throws {
        let source = """
        @startuml
        object alice
        object bob
        alice --> bob
        @enduml
        """
        let fixture = RoundTripFixture(path: "plantuml-object/inline", source: source)
        let cell = RoundTripCell(
            importer: PlantUMLImporter(),
            exporter: PlantUMLObjectExporter(),
            family: .classDiagram,
            allowedLosses: []
        )
        try runSameFormatRoundTrip(cell: cell, fixture: fixture)
    }
}
