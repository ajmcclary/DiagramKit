import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel
import DiagramKitTestSupport
@testable import DiagramKitPlantUML

@Suite("PlantUMLERRoundTripTests")
struct PlantUMLERRoundTripTests {

    @Test func basicERParsesEntitiesAndRelationships() throws {
        let source = """
        @startuml
        entity Customer {
          * id : number
          --
          name : text
          email : text
        }

        entity Order {
          * id : number
          --
          customer_id : number
          total : number
        }

        Customer ||--o{ Order
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .erDiagram(let er) = result.document.payload else {
            Issue.record("Expected erDiagram payload, got \(result.document.payload)"); return
        }
        #expect(er.entities.count == 2)
        #expect(er.entities[0].key == "Customer")
        #expect(er.entities[1].key == "Order")
        #expect(er.entities[0].attributes.first?.name == "id")
        #expect(er.entities[0].attributes.first?.keys.contains("PK") == true)
        #expect(er.relationships.count == 1)
        #expect(er.relationships[0].entity1 == "Customer")
        #expect(er.relationships[0].entity2 == "Order")
        #expect(result.diagnostics.isEmpty)
    }

    @Test func basicERRoundTripsLosslessly() throws {
        let source = """
        @startuml
        entity Customer {
          * id : number
          --
          name : text
          email : text
        }

        entity Order {
          * id : number
          --
          customer_id : number
          total : number
        }

        Customer ||--o{ Order
        @enduml
        """
        let fixture = RoundTripFixture(path: "plantuml-er/inline", source: source)
        let cell = RoundTripCell(
            importer: PlantUMLImporter(),
            exporter: PlantUMLExporter(),
            family: .erDiagram,
            allowedLosses: []
        )
        try runSameFormatRoundTrip(cell: cell, fixture: fixture)
    }
}
