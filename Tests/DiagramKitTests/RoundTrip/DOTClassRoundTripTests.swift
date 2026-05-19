import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitTestSupport
import DiagramKitModel
import DiagramKitGraphviz

@Suite("DOT class round-trip")
struct DOTClassRoundTripTests {

    @Test func basicClassRoundTripsThroughDOT() throws {
        let source = """
        digraph ClassExample {
          Animal [shape=record, label="{Animal|+ name: string\\l+ age: int\\l|+ sound(): void\\l}"];
          Dog [shape=record, label="{Dog|+ breed: string\\l|+ bark(): void\\l}"];
          Dog -> Animal;
        }
        """
        let cell = RoundTripCell(
            importer: GraphvizImporter(),
            exporter: DOTExporter(),
            family: DiagramType.classDiagram,
            allowedLosses: [.classStereotypeDrop, .styleDrop]
        )
        try runSameFormatRoundTrip(
            cell: cell,
            fixture: RoundTripFixture(path: "dot-class/inline-01", source: source)
        )
    }

    @Test func importerClassifiesAsClassDiagram() throws {
        let source = """
        digraph G {
          Animal [shape=record, label="{Animal|+ name: string\\l|}"];
        }
        """
        let result = try GraphvizImporter().parse(source)
        guard case .classDiagram(let cd) = result.document.payload else {
            Issue.record("Expected classDiagram payload, got \(result.document.payload.type)")
            return
        }
        #expect(cd.classes.count == 1)
        #expect(cd.classes[0].id == "Animal")
        #expect(cd.classes[0].label == "Animal")
        #expect(cd.classes[0].attributes.count == 1)
        #expect(cd.classes[0].attributes[0].id == "name")
    }
}
