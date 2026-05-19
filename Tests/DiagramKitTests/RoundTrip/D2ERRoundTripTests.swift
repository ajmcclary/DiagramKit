import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitTestSupport
import DiagramKitModel
import DiagramKitD2

@Suite("D2 ER round-trip")
struct D2ERRoundTripTests {

    @Test func basicERRoundTripsThroughD2() throws {
        let source = """
        Customer: {
          shape: sql_table
          id: number
          name: text
          email: text
        }

        Order: {
          shape: sql_table
          id: number
          customer_id: number
          total: number
        }

        Customer -> Order
        """
        let cell = RoundTripCell(
            importer: D2Importer(),
            exporter: D2Exporter(),
            family: DiagramType.erDiagram,
            allowedLosses: [.cardinalityDrop]
        )
        try runSameFormatRoundTrip(
            cell: cell,
            fixture: RoundTripFixture(path: "d2-er/inline-01", source: source)
        )
    }

    @Test func importerClassifiesAsERDiagram() throws {
        let source = """
        Customer: {
          shape: sql_table
          id: number
        }
        """
        let result = try D2Importer().parse(source)
        guard case .erDiagram(let er) = result.document.payload else {
            Issue.record("Expected erDiagram payload, got \(result.document.payload.type)")
            return
        }
        #expect(er.entities.count == 1)
        #expect(er.entities[0].key == "Customer")
        #expect(er.entities[0].attributes.count == 1)
        #expect(er.entities[0].attributes[0].name == "id")
        #expect(er.entities[0].attributes[0].type == "number")
    }
}
