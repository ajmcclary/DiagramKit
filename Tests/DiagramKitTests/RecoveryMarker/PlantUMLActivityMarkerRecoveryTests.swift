import Testing
import DiagramKitModel
@testable import DiagramKitPlantUML

@Suite("PlantUML activity marker recovery — id preservation")
struct PlantUMLActivityMarkerRecoveryTests {

    @Test("activity-original-id marker recovers non-synthetic node id on re-import")
    func markerRecoversOriginalId() throws {
        let source = """
        @startuml
        start
        :place order;
        ' diagramkit:activity-original-id=n_1,placeOrder
        stop
        @enduml
        """
        let parsed = try PlantUMLImporter().parse(source)
        guard case .flowchart(let graph) = parsed.document.payload else {
            Issue.record("expected flowchart payload, got: \(parsed.document.payload)")
            return
        }
        let ids = graph.nodesInOrder.map(\.id)
        #expect(ids.contains("placeOrder"),
                "expected placeOrder id to be recovered; got: \(ids)")
    }

    @Test("absent marker leaves synthetic id in place")
    func absentMarkerNoRecovery() throws {
        let source = """
        @startuml
        start
        :place order;
        stop
        @enduml
        """
        let parsed = try PlantUMLImporter().parse(source)
        guard case .flowchart(let graph) = parsed.document.payload else {
            Issue.record("expected flowchart payload")
            return
        }
        let ids = graph.nodesInOrder.map(\.id)
        #expect(ids.contains("n_1"))
    }
}
