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

    func testErDiagramQuotedLabelPreservesOperatorsAndStripsInlineComments() throws {
        let document = try DiagramPipeline.parse("""
        erDiagram
          "A--B" ||--o{ "C..D" : label %% not a comment
        """)
        guard case .erDiagram(let er) = document.payload else {
            return XCTFail("Expected .erDiagram payload")
        }
        let labels = Set(er.entities.map { $0.label })
        XCTAssertTrue(labels.contains("A--B"))
        XCTAssertTrue(labels.contains("C..D"))
        let rel = try XCTUnwrap(er.relationships.first)
        XCTAssertEqual(rel.label, "label")
    }

    // MARK: - Review remediation: C2 / C3 / M-PAR-4 / M-PAR-6

    func testFlowchartApostropheInUnquotedLabelDoesNotSwallowFollowingLines() throws {
        let document = try DiagramPipeline.parse("""
        flowchart TD
          A[Don't panic] --> B[Keep calm]
          B --> C[Done]
        """)
        guard case .flowchart(let graph) = document.payload else {
            return XCTFail("Expected .flowchart payload")
        }
        XCTAssertEqual(graph.nodesInOrder.count, 3)
        let labels = graph.nodesInOrder.map { $0.node.label }
        XCTAssertTrue(labels.contains("Don't panic"))
        XCTAssertTrue(labels.contains("Keep calm"))
        XCTAssertTrue(labels.contains("Done"))
        XCTAssertEqual(graph.edges.count, 2)
    }

    func testFlowchartNoSpaceArrowCreatesNodeBAndEdge() throws {
        let document = try DiagramPipeline.parse("""
        graph TD
          A-->B
        """)
        guard case .flowchart(let graph) = document.payload else {
            return XCTFail("Expected .flowchart payload")
        }
        let ids = Set(graph.nodesInOrder.map { $0.id })
        XCTAssertTrue(ids.contains("A"))
        XCTAssertTrue(ids.contains("B"))
        XCTAssertEqual(graph.edges.count, 1)
        XCTAssertEqual(graph.edges.first?.source, "A")
        XCTAssertEqual(graph.edges.first?.target, "B")
    }

    func testFlowchartTextEmbeddedLabelPicksEarliestCloser() throws {
        let document = try DiagramPipeline.parse("""
        flowchart TD
          A == label ==> B --> C
        """)
        guard case .flowchart(let graph) = document.payload else {
            return XCTFail("Expected .flowchart payload")
        }
        XCTAssertEqual(graph.edges.count, 2)
        let first = try XCTUnwrap(graph.edges.first)
        XCTAssertEqual(first.source, "A")
        XCTAssertEqual(first.target, "B")
        XCTAssertEqual(first.label, "label")
        let second = try XCTUnwrap(graph.edges.dropFirst().first)
        XCTAssertEqual(second.source, "B")
        XCTAssertEqual(second.target, "C")
    }

    func testFlowchartC4DirectionDoesNotMatchInsideRelLabel() throws {
        let document = try DiagramPipeline.parse("""
        C4Context
          Rel(a, b, "Set direction LR here")
        """)
        guard case .c4(let c4) = document.payload else {
            return XCTFail("Expected .c4 payload")
        }
        XCTAssertEqual(c4.relationships.count, 1)
        let rel = try XCTUnwrap(c4.relationships.first)
        XCTAssertEqual(rel.label, "Set direction LR here")
    }
}
