import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitTestSupport
import DiagramKitModel
import DiagramKitGraphviz

@Suite("DOT state round-trip")
struct DOTStateRoundTripTests {

    @Test func basicStateRoundTripsThroughDOT() throws {
        let source = """
        digraph StateMachine {
          _start [shape=point, style=filled, fillcolor=black];
          _end [shape=doublecircle, style=filled, fillcolor=black];

          _start -> Idle;
          Idle -> Active [label="trigger"];
          Active -> Done [label="complete"];
          Done -> _end;
        }
        """
        let cell = RoundTripCell(
            importer: GraphvizImporter(),
            exporter: DOTExporter(),
            family: DiagramType.stateDiagram,
            allowedLosses: [.stateActionDrop]
        )
        try runSameFormatRoundTrip(
            cell: cell,
            fixture: RoundTripFixture(path: "dot-state/inline-01", source: source)
        )
    }

    @Test func importerClassifiesAsStateDiagram() throws {
        let source = """
        digraph G {
          _start [shape=point];
          _start -> Idle;
        }
        """
        let result = try GraphvizImporter().parse(source)
        guard case .stateDiagram(let graph) = result.document.payload else {
            Issue.record("Expected stateDiagram payload, got \(result.document.payload.type)")
            return
        }
        #expect(graph.nodesInOrder.contains(where: { $0.id == "_start" && $0.node.shape == .stateStart }))
        #expect(graph.nodesInOrder.contains(where: { $0.id == "Idle" && $0.node.shape == .state }))
    }
}
