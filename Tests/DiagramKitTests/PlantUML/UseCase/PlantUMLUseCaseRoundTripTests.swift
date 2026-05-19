import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel
import DiagramKitTestSupport
@testable import DiagramKitPlantUML

@Suite("PlantUMLUseCaseRoundTripTests")
struct PlantUMLUseCaseRoundTripTests {

    @Test func basicUseCaseParsesToFlowchart() throws {
        let source = """
        @startuml
        :Customer: as customer
        :Admin: as admin
        (Login) as UC1
        (View Profile) as UC2
        (Edit Profile) as UC3

        customer --> UC1
        customer --> UC2
        admin --> UC3
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload, got \(result.document.payload)"); return
        }
        #expect(graph.nodesInOrder.count == 5)
        #expect(graph.edges.count == 3)
        let actorDiagnostics = result.diagnostics.filter { $0.category == .styleDrop }
        #expect(actorDiagnostics.count == 2)
    }

    @Test func basicUseCaseRoundTripsViaWrapper() throws {
        let source = """
        @startuml
        :Customer: as customer
        (Login) as UC1
        (View Profile) as UC2

        customer --> UC1
        customer --> UC2
        @enduml
        """
        let fixture = RoundTripFixture(path: "plantuml-usecase/inline", source: source)
        let cell = RoundTripCell(
            importer: PlantUMLImporter(),
            exporter: PlantUMLUseCaseExporter(),
            family: .flowchart,
            allowedLosses: []
        )
        try runSameFormatRoundTrip(cell: cell, fixture: fixture)
    }
}
