import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel
import DiagramKitTestSupport
@testable import DiagramKitPlantUML

@Suite("PlantUMLComponentRoundTripTests")
struct PlantUMLComponentRoundTripTests {

    @Test func basicComponentParsesToArchitecture() throws {
        let source = """
        @startuml
        [Web] --> [API]
        interface HTTP
        [API] --> HTTP
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .architecture(let arch) = result.document.payload else {
            Issue.record("Expected architecture payload, got \(result.document.payload)"); return
        }
        let ids = arch.services.map(\.id).sorted()
        #expect(ids == ["API", "HTTP", "Web"])
        #expect(arch.edges.count == 2)
        let interfaceDiagnostics = result.diagnostics.filter { $0.category == .styleDrop }
        #expect(interfaceDiagnostics.count == 1)
    }

    @Test func basicComponentRoundTripsThroughExporter() throws {
        let source = """
        @startuml
        [Web] --> [API]
        [API] --> [Database]
        @enduml
        """
        let fixture = RoundTripFixture(path: "plantuml-component/inline", source: source)
        let cell = RoundTripCell(
            importer: PlantUMLImporter(),
            exporter: PlantUMLExporter(),
            family: .architecture,
            allowedLosses: []
        )
        try runSameFormatRoundTrip(cell: cell, fixture: fixture)
    }
}
