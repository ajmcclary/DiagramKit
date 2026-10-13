// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import XCTest
import CustomDump
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class DiagramEngineSmokeTests: XCTestCase {
    func testVersionIsNonEmpty() {
        XCTAssertFalse(DiagramEngine.version.isEmpty)
    }

    func testFlowSvgContainsNodes() async throws {
        let svg = try await DiagramEngine.renderSVG(
            source: """
            graph TD
              A[Start] --> B[End]
            """
        )
        XCTAssertTrue(svg.contains("class=\"node\""), "Expected flow SVG to include rendered nodes")
    }

    @MainActor
    func testRenderImageForSimpleFlowIsNonNil() async throws {
        let image = try await DiagramEngine.renderImage(
            source: """
            graph TD
              A[Start] --> B[End]
            """
        )
        XCTAssertNotNil(image, "Expected DiagramEngine.renderImage to return a rasterizable image")
    }

    func testStringDiagramExtensionsUseFormatNeutralNames() async throws {
        let source = """
        graph TD
          A[Start] --> B[End]
        """

        let graph = try await source.parseDiagram()
        XCTAssertEqual(graph.type, .flowchart)

        let svg = try await source.renderDiagramSVG()
        XCTAssertTrue(svg.contains("<svg"), "Expected format-neutral String SVG helper to render SVG")

        let ascii = try await source.renderDiagramASCII()
        XCTAssertFalse(ascii.isEmpty, "Expected format-neutral String ASCII helper to render ASCII")
    }

    @MainActor
    func testStringRenderDiagramImageForSimpleFlowIsNonNil() async throws {
        let source = """
        graph TD
          A[Start] --> B[End]
        """

        let image = try await source.renderDiagramImage()
        XCTAssertNotNil(image, "Expected format-neutral String image helper to return a rasterizable image")
    }

    /// Reproduces crash in flow-15 (subgraph with direction override).
    func testFlow15SubgraphDirectionCrash() async throws {
        let source = """
        graph TD
          subgraph pipeline [Processing Pipeline]
            direction LR
            A[Input] --> B[Parse] --> C[Transform] --> D[Output]
          end
          E[Source] --> A
          D --> F[Sink]
        """
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertFalse(svg.isEmpty)
    }

    /// Reproduces LongEdgeJoiner crash on state-2-composite.
    func testState2CompositeCrash() async throws {
        let source = """
        stateDiagram-v2
          [*] --> Idle
          Idle --> Processing : submit
          state Processing {
            parse --> validate
            validate --> execute
          }
          Processing --> Complete : done
          Processing --> Error : fail
          Error --> Idle : retry
          Complete --> [*]
        """
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertFalse(svg.isEmpty)
    }

    func testStateDiagramWithYamlFrontMatter() async throws {
        let source = """
        ---
        title: Simple sample
        ---
        stateDiagram-v2
            [*] --> Still
            Still --> [*]
            Still: Standing by

            Still --> Moving : start moving
            Moving --> Still : stop moving
            Moving --> Crash : impact
            Crash --> [*]
        """

        let graph = try await DiagramEngine.parse(source)
        expectNoDifference(graph.type, .stateDiagram)

        let positioned = try await DiagramEngine.layout(source)
        let userStateIDs = Set(["Crash", "Moving", "Still"])
        let nodeIDs = (positioned.flowchartNodes ?? [])
            .map(\.id)
            .filter { userStateIDs.contains($0) }
            .sorted()
        expectNoDifference(nodeIDs, ["Crash", "Moving", "Still"])

        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertTrue(svg.contains("<svg"), "Expected frontmatter state diagram to render SVG")
        XCTAssertTrue(svg.contains("start moving"), "Expected transition label text to render in SVG")

        let ascii = try await DiagramEngine.renderASCII(source: source).text
        XCTAssertFalse(ascii.isEmpty, "Expected frontmatter state diagram to render ASCII")
    }

    @MainActor
    func testLayerClearsPreparedDiagramWhenSourceBecomesInvalid() async throws {
        DiagramEngine.bootstrap()
        let layer = DiagramLayer()
        layer.source = """
        graph TD
          A[Start] --> B[End]
        """

        try await waitUntil("Expected initial diagram to prepare") {
            layer.preparedDiagram != nil
        }

        XCTAssertNotEqual(layer.diagramBounds, .zero)

        layer.source = "not a diagram"

        try await waitUntil("Expected invalid source to publish parse error") {
            layer.parseError != nil
        }

        // Clear-on-failure semantics (see DiagramLayer.prepareDiagram): a
        // failed parse must surface as `preparedDiagram == nil` so bindings
        // consumers can observe the transition rather than rendering stale
        // geometry alongside a floating parseError.
        XCTAssertNil(layer.preparedDiagram)
        XCTAssertEqual(layer.diagramBounds, .zero)
    }

    func testFlow6EdgeStyles() async throws {
        let source = "graph TD\n  A[Source] -->|solid| B[Target 1]\n  A -.->|dotted| C[Target 2]\n  A ==>|thick| D[Target 3]"
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertFalse(svg.isEmpty)
    }

    func testFlow8BidirectionalEdgeLabels() async throws {
        let source = "graph LR\n  A[Client] <-->|sync| B[Server]\n  B <-.->|heartbeat| C[Monitor]\n  C <==>|data| D[Storage]"
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertFalse(svg.isEmpty)
    }

    @MainActor
    private func waitUntil(
        _ failureMessage: String,
        predicate: @MainActor () -> Bool
    ) async throws {
        for _ in 0..<100 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail(failureMessage)
    }

    func testSimpleTDNodeOrder() async throws {
        let source = "graph TD\n  A[Start] --> B[End]"
        let pos = try await DiagramEngine.layout(source)
        let nodes = pos.flowchartNodes!
        expectNoDifference(nodes.map(\.id).sorted(), ["A", "B"])
        let nodeA = nodes.first { $0.id == "A" }!
        let nodeB = nodes.first { $0.id == "B" }!
        XCTAssertLessThan(nodeA.y, nodeB.y, "In graph TD, source A should be above target B (lower y)")
    }

    func testSimpleBTNodeOrder() async throws {
        let source = "graph BT\n  A[Foundation] --> B[Layer 2] --> C[Top]"
        let pos = try await DiagramEngine.layout(source)
        let nodes = pos.flowchartNodes!
        expectNoDifference(nodes.map(\.id).sorted(), ["A", "B", "C"])
        let nodeA = nodes.first { $0.id == "A" }!
        let nodeC = nodes.first { $0.id == "C" }!
        XCTAssertGreaterThan(nodeA.y, nodeC.y, "In graph BT, source A should be below target C (higher y)")
    }

    /// Regression bar for the cross-subgraph edge fix: edges from an
    /// outside node into nodes nested two subgraph levels deep must survive
    /// layout with routable geometry (previously silently dropped).
    func testFlow14NestedSubgraphCrossSubgraphEdges() async throws {
        let source = """
        graph TD
          subgraph Cloud
            subgraph us-east [US East Region]
              A[Web Server] --> B[App Server]
            end
            subgraph us-west [US West Region]
              C[Web Server] --> D[App Server]
            end
          end
          E[Load Balancer] --> A
          E --> C
        """
        let pos = try await DiagramEngine.layout(source)
        let nodes = pos.flowchartNodes!
        let edges = pos.flowchartEdges!
        let groups = pos.flowchartGroups!

        expectNoDifference(nodes.map(\.id).sorted(), ["A", "B", "C", "D", "E"])

        // Both cross-subgraph edges (E → nested-in-Cloud members) survive.
        for (from, to) in [("E", "A"), ("E", "C")] {
            let edge = edges.first { $0.source == from && $0.target == to }
            XCTAssertNotNil(edge, "cross-subgraph edge \(from)→\(to) was dropped")
            guard let points = edge?.points else { continue }
            XCTAssertGreaterThanOrEqual(points.count, 2, "\(from)→\(to) has no routable geometry")
            for p in points {
                XCTAssertTrue(p.x.isFinite && p.y.isFinite, "\(from)→\(to) point not finite: \(p)")
            }
        }

        // Nesting structure survived: Cloud contains the two regions.
        let cloud = groups.first { $0.id == "Cloud" }
        XCTAssertNotNil(cloud)
        expectNoDifference(
            cloud?.children.map(\.id).sorted(), ["us-east", "us-west"])

        // Every node landed with positive, finite geometry.
        for n in nodes {
            XCTAssertTrue(n.width.isFinite && n.height.isFinite && n.width > 0 && n.height > 0,
                          "node \(n.id) has degenerate geometry")
        }
    }

    /// Styled fan-out edges (solid / dotted / thick) keep full geometry in
    /// both orientations (graph TD goes through the GraphTransformer
    /// rotation; graph LR does not). Deliberately unlabeled: labeled
    /// `-->|text|` flowchart edges are a known pre-existing parser gap
    /// (the label syntax drops the edge silently — see corpus entry
    /// `flow-6-edge-styles`, whose baselines contain only the source
    /// node); fixing that is a parser behavior change outside this phase.
    func testFlow6PortOrder() async throws {
        func assertStyledFanOut(_ source: String, orientation: String) async throws {
            let pos = try await DiagramEngine.layout(source)
            let nodes = pos.flowchartNodes!
            let edges = pos.flowchartEdges!
            expectNoDifference(nodes.map(\.id).sorted(), ["A", "B", "C", "D"])
            expectNoDifference(edges.map { "\($0.source)->\($0.target)" }.sorted(),
                               ["A->B", "A->C", "A->D"])
            for edge in edges {
                XCTAssertGreaterThanOrEqual(edge.points.count, 2,
                                            "\(orientation) \(edge.source)->\(edge.target) has no routable geometry")
                for p in edge.points {
                    XCTAssertTrue(p.x.isFinite && p.y.isFinite,
                                  "\(orientation) \(edge.source)->\(edge.target) point not finite: \(p)")
                }
            }
        }

        // graph TD (has GraphTransformer rotation)
        try await assertStyledFanOut(
            "graph TD\n  A[Source] --> B[Target 1]\n  A -.-> C[Target 2]\n  A ==> D[Target 3]",
            orientation: "TD")
        // graph LR (no rotation)
        try await assertStyledFanOut(
            "graph LR\n  A[Source] --> B[Target 1]\n  A -.-> C[Target 2]\n  A ==> D[Target 3]",
            orientation: "LR")
    }
}
#endif
