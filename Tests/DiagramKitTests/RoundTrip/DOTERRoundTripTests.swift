import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitTestSupport
import DiagramKitModel
import DiagramKitGraphviz

@Suite("DOT ER round-trip")
struct DOTERRoundTripTests {

    @Test func basicERRoundTripsThroughDOT() throws {
        let source = """
        digraph EREXample {
          Customer [shape=record, label="{Customer|id: number\\nname: text\\nemail: text\\n}"];
          Order [shape=record, label="{Order|id: number\\ncustomer_id: number\\ntotal: number\\n}"];
          Customer -> Order;
        }
        """
        let cell = RoundTripCell(
            importer: GraphvizImporter(),
            exporter: DOTExporter(),
            family: DiagramType.erDiagram,
            allowedLosses: [.cardinalityDrop]
        )
        try runSameFormatRoundTrip(
            cell: cell,
            fixture: RoundTripFixture(path: "dot-er/inline-01", source: source)
        )
    }

    @Test func importerClassifiesAsERDiagram() throws {
        let source = """
        digraph G {
          Customer [shape=record, label="{Customer|id: number\\nname: text\\n}"];
        }
        """
        let result = try GraphvizImporter().parse(source)
        guard case .erDiagram(let er) = result.document.payload else {
            Issue.record("Expected erDiagram payload, got \(result.document.payload.type)")
            return
        }
        #expect(er.entities.count == 1)
        #expect(er.entities[0].key == "Customer")
        #expect(er.entities[0].attributes.count == 2)
    }
}
