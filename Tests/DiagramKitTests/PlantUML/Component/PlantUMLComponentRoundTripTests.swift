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
        // Interface vs component now flows through ArchitectureService.kind
        // instead of dropping with a styleDrop diagnostic.
        let interfaceDiagnostics = result.diagnostics.filter { $0.category == .styleDrop }
        #expect(interfaceDiagnostics.isEmpty,
                "interface-vs-component now lives on kind, no styleDrop expected; got \(interfaceDiagnostics)")
        let http = arch.services.first { $0.id == "HTTP" }
        #expect(http?.kind == .interface)
        let web = arch.services.first { $0.id == "Web" }
        let api = arch.services.first { $0.id == "API" }
        #expect(web?.kind == .component)
        #expect(api?.kind == .component)
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
