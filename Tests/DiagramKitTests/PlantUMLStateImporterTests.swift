import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitPlantUML

@Suite struct PlantUMLStateImporterTests {

    @Test("Parses simple state transitions including initial/final pseudostates")
    func basicStateMachine() throws {
        let source = """
        @startuml
        [*] --> Idle
        Idle --> Working : start
        Working --> [*]
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .stateDiagram(let graph) = result.document.payload else {
            Issue.record("Expected stateDiagram payload, got \(result.document.payload)")
            return
        }
        let nodeIds = Set(graph.nodesInOrder.map(\.id))
        #expect(nodeIds.contains("Idle"))
        #expect(nodeIds.contains("Working"))
        // Pseudostates mapped to root_start / root_end conventionally
        let startNode = graph.nodesInOrder.first(where: { $0.node.shape == .stateStart })
        let endNode = graph.nodesInOrder.first(where: { $0.node.shape == .stateEnd })
        #expect(startNode != nil)
        #expect(endNode != nil)
        // Confirm transition labels survive
        let startEdge = graph.edges.first(where: { $0.target == "Working" })
        #expect(startEdge?.label == "start")
    }

    @Test("Parses state with description after colon")
    func stateWithDescription() throws {
        let source = """
        @startuml
        state Idle : Waiting for input
        state Working
        Idle --> Working
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .stateDiagram(let graph) = result.document.payload else {
            Issue.record("Expected stateDiagram payload"); return
        }
        let idle = graph.nodesInOrder.first(where: { $0.id == "Idle" })
        #expect(idle?.node.label == "Waiting for input")
    }

    @Test("Composite state emits a subgraph containing children")
    func compositeState() throws {
        let source = """
        @startuml
        state Outer {
          [*] --> Inner1
          Inner1 --> Inner2
          Inner2 --> [*]
        }
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .stateDiagram(let graph) = result.document.payload else {
            Issue.record("Expected stateDiagram payload"); return
        }
        #expect(!graph.subgraphs.isEmpty)
        let outer = graph.subgraphs.first(where: { $0.label == "Outer" })
        #expect(outer != nil)
        #expect(outer?.nodeIds.contains("Inner1") == true)
        #expect(outer?.nodeIds.contains("Inner2") == true)
    }

    @Test("Activity syntax now routes to flowchart payload (Wave 1)")
    func activityShortForm() throws {
        let source = """
        @startuml
        start
        :Do step 1;
        :Do step 2;
        stop
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .flowchart(let graph) = result.document.payload else {
            Issue.record("Expected flowchart payload, got \(result.document.payload)"); return
        }
        let labels = graph.nodesInOrder.map(\.node.label)
        #expect(labels.contains(where: { $0.contains("Do step 1") }))
        #expect(labels.contains(where: { $0.contains("Do step 2") }))
        #expect(labels.contains("start"))
        #expect(labels.contains("stop"))
        #expect(graph.edges.count >= 3)
    }
}
