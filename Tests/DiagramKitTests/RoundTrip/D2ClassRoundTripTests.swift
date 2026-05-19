import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitTestSupport
import DiagramKitModel
import DiagramKitD2

@Suite("D2 class round-trip")
struct D2ClassRoundTripTests {

    @Test func basicClassRoundTripsThroughD2() throws {
        let source = """
        Animal: {
          shape: class
          +name: string
          +age: int
          +sound(): void
        }

        Dog: {
          shape: class
          +breed: string
          +bark(): void
        }

        Dog -> Animal
        """
        let cell = RoundTripCell(
            importer: D2Importer(),
            exporter: D2Exporter(),
            family: DiagramType.classDiagram,
            allowedLosses: [.classStereotypeDrop, .styleDrop]
        )
        try runSameFormatRoundTrip(
            cell: cell,
            fixture: RoundTripFixture(path: "d2-class/inline-01", source: source)
        )
    }

    @Test func importerClassifiesAsClassDiagram() throws {
        let source = """
        Animal: {
          shape: class
          +name: string
        }
        """
        let result = try D2Importer().parse(source)
        guard case .classDiagram(let cd) = result.document.payload else {
            Issue.record("Expected classDiagram payload, got \(result.document.payload.type)")
            return
        }
        #expect(cd.classes.count == 1)
        #expect(cd.classes[0].id == "Animal")
        #expect(cd.classes[0].attributes.count == 1)
        #expect(cd.classes[0].attributes[0].id == "name")
    }
}
