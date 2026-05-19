import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitTestSupport
import DiagramKitModel
import DiagramKitD2

@Suite("D2 state round-trip")
struct D2StateRoundTripTests {

    @Test func basicStateRoundTripsThroughD2() throws {
        let source = """
        _start: {
          shape: circle
        }
        _end: {
          shape: circle
        }

        _start -> Idle
        Idle -> Active: trigger
        Active -> Done: complete
        Done -> _end
        """
        let cell = RoundTripCell(
            importer: D2Importer(),
            exporter: D2Exporter(),
            family: DiagramType.stateDiagram,
            allowedLosses: [.stateActionDrop]
        )
        try runSameFormatRoundTrip(
            cell: cell,
            fixture: RoundTripFixture(path: "d2-state/inline-01", source: source)
        )
    }

    @Test func importerClassifiesAsStateDiagram() throws {
        let source = """
        _start -> Idle
        """
        let result = try D2Importer().parse(source)
        guard case .stateDiagram(let graph) = result.document.payload else {
            Issue.record("Expected stateDiagram payload, got \(result.document.payload.type)")
            return
        }
        let startNode = graph.nodesInOrder.first(where: { $0.id == "_start" })
        #expect(startNode?.node.shape == .stateStart)
        let idleNode = graph.nodesInOrder.first(where: { $0.id == "Idle" })
        #expect(idleNode?.node.shape == .state)
    }
}
