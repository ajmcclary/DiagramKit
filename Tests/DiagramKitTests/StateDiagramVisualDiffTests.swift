import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class StateDiagramVisualDiffTests: XCTestCase {

    // MARK: - Structural SVG assertions for canonical state diagram fixtures

    func testSimpleLinearTransitionProducesSvgWithNodes() async throws {
        let source = """
        stateDiagram-v2
          [*] --> A
          A --> B
          B --> [*]
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("statediagram-state"), "State nodes should have statediagram-state class")
        XCTAssertTrue(svg.contains("class=\"edge transition"), "Edges should have transition class")
        XCTAssertTrue(svg.contains("A"), "Node A should be present")
        XCTAssertTrue(svg.contains("B"), "Node B should be present")
    }

    func testCompositeWithDescriptionsRendersCorrectly() async throws {
        let source = """
        stateDiagram-v2
          state Active {
            parse : Parsing
            parse : Input
            validate --> execute
          }
          [*] --> Active
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("statediagram-cluster"), "Composite should have cluster class")
        XCTAssertTrue(svg.contains("data-shape=\"rect-with-title\"") || svg.contains("rect-with-title"),
                        "Description state should use rect-with-title shape")
        XCTAssertTrue(svg.contains("validate") && svg.contains("execute"),
                        "Inner transition nodes should be present")
    }

    func testChoiceForkJoinRendersPseudoShapes() async throws {
        let source = """
        stateDiagram-v2
          state if_state <<choice>>
          state fork_state <<fork>>
          state join_state <<join>>
          [*] --> if_state
          if_state --> fork_state
          fork_state --> join_state
          join_state --> [*]
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("data-shape=\"choice\""), "Choice node should use choice shape")
        XCTAssertTrue(svg.contains("data-shape=\"fork\""), "Fork node should use fork shape")
        XCTAssertTrue(svg.contains("data-shape=\"join\""), "Join node should use join shape")
    }

    func testConcurrentRegionsRendersSubgraphs() async throws {
        let source = """
        stateDiagram-v2
          state Composite {
            [*] --> A1
            A1 --> A2
            --
            [*] --> B1
          }
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("statediagram-cluster"), "Composite should have cluster class")
        // Region subgraphs should exist
        XCTAssertTrue(svg.contains("Composite_region_0") || svg.contains("Composite_region"),
                       "Concurrent region subgraph should be present")
        // No raw divider nodes
        XCTAssertFalse(svg.contains("_divider_"), "Divider IDs should not appear in SVG")
    }

    func testNotesStyledRendersWithNoteClasses() async throws {
        let source = """
        stateDiagram-v2
          [*] --> Idle
          note right of Idle : Right note
          note left of Idle : Left note
          note "Floating note" as N1
          classDef highlight fill:#f9f
          class Idle highlight
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("statediagram-note"), "Notes should have statediagram-note class")
        XCTAssertTrue(svg.contains("note-edge"), "Note edges should have note-edge class")
        XCTAssertTrue(svg.contains("statediagram-state"), "State nodes should have state class")
        XCTAssertTrue(svg.contains("Floating note"), "Floating note should be present")
    }

    func testClickHrefRendersSvgAnchor() async throws {
        let source = """
        stateDiagram-v2
          [*] --> Home
          Home --> About : go
          click Home href "https://example.com" "Go to Example"
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("<a "), "Should have anchor tag for clickable node")
        XCTAssertTrue(svg.contains("xlink:href=\"https://example.com\""), "Should have href")
        XCTAssertTrue(svg.contains("target=\"_blank\""), "Should have target _blank")
        XCTAssertTrue(svg.contains("title=\"Go to Example\""), "Should have tooltip")
    }

    func testAccessibilityDirectivesRenderSvgMetadata() async throws {
        let source = """
        stateDiagram-v2
          accTitle: My State Diagram
          accDescr: This diagram shows state transitions
          [*] --> Idle
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("<title>My State Diagram</title>"))
        XCTAssertTrue(svg.contains("<desc>This diagram shows state transitions</desc>"))
    }

    func testFullComplexDiagramRendersAllFeatures() async throws {
        let source = """
        stateDiagram-v2
          [*] --> Idle
          Idle --> Processing : submit
          state Processing {
            [*] --> Queued
            Queued --> Running : dequeue
            state if_state <<choice>>
            Running --> if_state
            if_state --> Done : success
            if_state --> Failed : error
            --
            note right of Running : Active job
          }
          Processing --> Complete : done
          Processing --> Error : fail
          Error --> Idle : retry
          Complete --> [*]
          classDef highlight fill:#f9f
          class Processing highlight
        """
        let svg = try await MermaidRenderer.renderSVG(source: source)
        // Must contain all key elements
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("statediagram-cluster"), "Composite should render")
        XCTAssertTrue(svg.contains("statediagram-state"), "State nodes should render")
        XCTAssertTrue(svg.contains("class=\"edge transition"), "Edges should render")
        XCTAssertTrue(svg.contains("statediagram-note"), "Notes should render")
        XCTAssertTrue(svg.contains("data-shape=\"choice\""), "Choice pseudo-node should render")
        // Concurrent regions should produce subgraphs
        XCTAssertTrue(svg.contains("Processing_region_0") || svg.contains("Processing_region"),
                       "Concurrent region subgraph should exist")
    }
}
