import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel
import DiagramKitTestSupport
@testable import DiagramKitPlantUML

@Suite("PlantUMLActivityRoundTripTests")
struct PlantUMLActivityRoundTripTests {

    @Test func basicActivityParsesToFlowchart() throws {
        let source = """
        @startuml
        start
        :Receive request;
        :Validate;
        :Process;
        stop
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload, got \(result.document.payload)"); return
        }
        #expect(graph.nodesInOrder.count == 5)
        #expect(graph.edges.count == 4)
        #expect(graph.nodesInOrder.first?.node.label == "start")
        #expect(graph.nodesInOrder.last?.node.label == "stop")
        #expect(result.diagnostics.isEmpty)
    }

    @Test func basicActivityRoundTripsThroughExporter() throws {
        let source = """
        @startuml
        start
        :Receive request;
        :Validate;
        :Process;
        stop
        @enduml
        """
        let fixture = RoundTripFixture(path: "plantuml-activity/inline", source: source)
        let cell = RoundTripCell(
            importer: PlantUMLImporter(),
            exporter: PlantUMLExporter(),
            family: .flowchart,
            allowedLosses: []
        )
        try runSameFormatRoundTrip(cell: cell, fixture: fixture)
    }

    @Test func partitionSurfacesAsSubgraph() throws {
        let source = """
        @startuml
        start
        partition "Backend" {
          :Validate;
          :Process;
        }
        stop
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload"); return
        }
        // Partitions now lift into MermaidSubgraph entries instead of
        // dropping with a subgraphFlatten diagnostic.
        #expect(!result.diagnostics.contains(where: { $0.category == .subgraphFlatten }),
                "subgraphFlatten diagnostic should no longer fire; got \(result.diagnostics)")
        #expect(graph.subgraphs.contains(where: { $0.label == "Backend" }),
                "Expected `Backend` partition to surface as a subgraph; got \(graph.subgraphs.map { $0.label })")
    }
}
