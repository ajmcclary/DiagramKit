import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// Dedicated parser/layout invariants for the three highest-traffic
/// diagram families (Phase 6F). Corpus snapshots remain the only
/// guardrail for the rendered output; these tests fail when the
/// parser or layout itself drifts, decoupling regressions from
/// snapshot-baseline churn.
final class FlowchartStateERReviewRegressionTests: XCTestCase {

    // MARK: - Flowchart

    func testFlowchartParsesDirectionAndEdgeCount() throws {
        let document = try DiagramPipeline.parse("""
        flowchart LR
          A --> B
          B --> C
          A --> C
        """)
        guard case .flowchart(let graph) = document.payload else {
            return XCTFail("Expected .flowchart payload, got \(document.type)")
        }
        XCTAssertEqual(graph.direction, .LR)
        XCTAssertEqual(graph.edges.count, 3)
        XCTAssertEqual(graph.nodesInOrder.count, 3)
    }

    func testFlowchartSubgraphCapturesChildNodes() throws {
        let document = try DiagramPipeline.parse("""
        flowchart TD
          subgraph cluster["Cluster"]
            X --> Y
          end
          Z --> X
        """)
        guard case .flowchart(let graph) = document.payload else {
            return XCTFail("Expected .flowchart payload")
        }
        XCTAssertEqual(graph.subgraphs.count, 1)
        let cluster = try XCTUnwrap(graph.subgraphs.first)
        XCTAssertEqual(cluster.id, "cluster")
        XCTAssertTrue(cluster.nodeIds.contains("X"))
        XCTAssertTrue(cluster.nodeIds.contains("Y"))
    }

    func testFlowchartEdgeStyleSurvivesParse() throws {
        let document = try DiagramPipeline.parse("""
        flowchart LR
          A --> B
          C -.-> D
          E === F
        """)
        guard case .flowchart(let graph) = document.payload else {
            return XCTFail("Expected .flowchart payload")
        }
        XCTAssertEqual(graph.edges.count, 3)
        // Solid `-->`, dotted `-.->`, and thick `===` must produce edges
        // with distinct style values — if the parser collapses them, the
        // renderer would lose the visual variant on every flowchart.
        let styles = Set(graph.edges.map { $0.style })
        XCTAssertGreaterThan(styles.count, 1,
                             "Expected multiple edge style variants; got \(styles)")
    }

    // MARK: - State

    func testStateDiagramParsesNodesAndTransitions() throws {
        let document = try DiagramPipeline.parse("""
        stateDiagram-v2
          [*] --> Idle
          Idle --> Working : start
          Working --> Idle : finish
          Working --> [*]
        """)
        guard case .stateDiagram(let graph) = document.payload else {
            return XCTFail("Expected .state payload, got \(document.type)")
        }
        XCTAssertGreaterThanOrEqual(graph.edges.count, 4)
        // [*] is the canonical start/end placeholder; both Idle and Working
        // should appear as real nodes.
        let ids = graph.nodesInOrder.map { $0.id }
        XCTAssertTrue(ids.contains("Idle"), "Missing 'Idle' node; got \(ids)")
        XCTAssertTrue(ids.contains("Working"), "Missing 'Working' node; got \(ids)")
        // Transition labels survive the parse.
        XCTAssertTrue(graph.edges.contains { $0.label == "start" })
        XCTAssertTrue(graph.edges.contains { $0.label == "finish" })
    }

    func testStateDiagramCompositeStateProducesSubgraph() throws {
        let document = try DiagramPipeline.parse("""
        stateDiagram-v2
          [*] --> Outer
          state Outer {
            [*] --> Inner
            Inner --> [*]
          }
          Outer --> [*]
        """)
        guard case .stateDiagram(let graph) = document.payload else {
            return XCTFail("Expected .state payload")
        }
        XCTAssertFalse(graph.subgraphs.isEmpty, "Composite state should produce a subgraph")
        let outer: original_src_types.MermaidSubgraph? = graph.subgraphs.first(where: { $0.id == "Outer" })
        let composite = try XCTUnwrap(outer)
        XCTAssertTrue(composite.nodeIds.contains("Inner"),
                      "Composite 'Outer' should contain 'Inner'; got \(composite.nodeIds)")
    }

    // MARK: - ER

    func testErDiagramParsesEntitiesAndRelationships() throws {
        // `parseMermaid` is the legacy entry-point that only supports the
        // built-in flowchart/state families. ER (and the rest of the 28
        // families) is dispatched through the registry-aware pipeline.
        let document = try DiagramPipeline.parse("""
        erDiagram
          CUSTOMER ||--o{ ORDER : places
          ORDER ||--|{ LINE_ITEM : contains
          CUSTOMER {
            string name
            string email
          }
        """)
        guard case .erDiagram(let er) = document.payload else {
            return XCTFail("Expected .erDiagram payload, got \(document.type)")
        }
        let labels = er.entities.map { $0.label }
        XCTAssertTrue(labels.contains("CUSTOMER"))
        XCTAssertTrue(labels.contains("ORDER"))
        XCTAssertTrue(labels.contains("LINE_ITEM"))
        XCTAssertGreaterThanOrEqual(er.relationships.count, 2)
        let customer: ErEntity? = er.entities.first(where: { $0.label == "CUSTOMER" })
        let customerUnwrapped = try XCTUnwrap(customer)
        XCTAssertGreaterThanOrEqual(customerUnwrapped.attributes.count, 2)
    }

    func testErDiagramLayoutPositionsEntitiesWithNonZeroSize() throws {
        let document = try DiagramPipeline.parse("""
        erDiagram
          A ||--o{ B : has
        """)
        guard case .erDiagram(let er) = document.payload else {
            return XCTFail("Expected .erDiagram payload")
        }
        let positioned = try layoutErDiagramSync(er)
        XCTAssertGreaterThan(positioned.width, 0)
        XCTAssertGreaterThan(positioned.height, 0)
        XCTAssertEqual(positioned.entities.count, 2)
        for entity in positioned.entities {
            XCTAssertGreaterThan(entity.width, 0)
            XCTAssertGreaterThan(entity.height, 0)
        }
    }
}
