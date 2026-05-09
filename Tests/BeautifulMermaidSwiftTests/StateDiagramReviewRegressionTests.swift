import XCTest
import CustomDump
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

final class StateDiagramReviewRegressionTests: XCTestCase {
    func testMultiDescriptionStateRendersTitleAndDescriptionBody() async throws {
        let source = """
        stateDiagram-v2
          LS : This is a title
          LS : This is the body
        """

        let positioned = try await MermaidRenderer.layout(source)
        let node = try XCTUnwrap(positioned.flowchartNodes?.first { $0.id == "LS" })
        expectNoDifference(node.shape, "rect-with-title")
        expectNoDifference(node.descriptions, ["This is a title", "This is the body"])

        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("This is a title"))
        XCTAssertTrue(svg.contains("This is the body"))
    }

    func testStateClickHrefAndQuotedUrlRenderAsSvgAnchor() async throws {
        let source = """
        stateDiagram-v2
          [*] --> Home
          click Home href "https://example.com" "Go to Example"
        """

        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("<a "))
        XCTAssertTrue(svg.contains("xlink:href=\"https://example.com\""))
        XCTAssertTrue(svg.contains("target=\"_blank\""))
        XCTAssertTrue(svg.contains("title=\"Go to Example\""))

        let quotedUrlSource = """
        stateDiagram-v2
          [*] --> Home
          click Home "https://example.com/quoted" "Quoted form"
        """
        let quotedUrlSvg = try await MermaidRenderer.renderSVG(source: quotedUrlSource)
        XCTAssertTrue(quotedUrlSvg.contains("xlink:href=\"https://example.com/quoted\""))
        XCTAssertTrue(quotedUrlSvg.contains("title=\"Quoted form\""))
    }

    func testStartAndEndClassShorthandAppliesToGeneratedEndpointIds() async throws {
        let source = """
        stateDiagram-v2
          classDef endpoint fill:#f9f,stroke:#333
          [*]:::endpoint --> Running
          Running --> [*]:::endpoint
        """

        let positioned = try await MermaidRenderer.layout(source)
        let nodes = Dictionary(uniqueKeysWithValues: (positioned.flowchartNodes ?? []).map { ($0.id, $0) })
        expectNoDifference(nodes["root_start"]?.inlineStyle["fill"], "#f9f")
        expectNoDifference(nodes["root_start"]?.inlineStyle["stroke"], "#333")
        expectNoDifference(nodes["root_end"]?.inlineStyle["fill"], "#f9f")
        expectNoDifference(nodes["root_end"]?.inlineStyle["stroke"], "#333")
    }

    func testMultilineStateNoteKeepsAllBodyLines() async throws {
        let source = """
        stateDiagram-v2
          State1
          note right of State1
            first note line
            second note line
          end note
        """

        let positioned = try await MermaidRenderer.layout(source)
        let note = try XCTUnwrap(positioned.flowchartNodes?.first { $0.id == "State1----note" })
        expectNoDifference(note.label, "first note line\nsecond note line")

        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("data-from=\"State1\" data-to=\"State1----note\" data-style=\"dotted\""))
        XCTAssertTrue(svg.contains("first note line"))
        XCTAssertTrue(svg.contains("second note line"))
    }

    func testForkAndJoinUseCompactBarGeometryAndNoLabel() async throws {
        let source = """
        stateDiagram-v2
          state fork_state <<fork>>
          state join_state <<join>>
          [*] --> fork_state
          fork_state --> join_state
          join_state --> [*]
        """

        let positioned = try await MermaidRenderer.layout(source)
        let fork = try XCTUnwrap(positioned.flowchartNodes?.first { $0.id == "fork_state" })
        let join = try XCTUnwrap(positioned.flowchartNodes?.first { $0.id == "join_state" })

        expectNoDifference(fork.shape, "fork")
        expectNoDifference(join.shape, "join")
        expectNoDifference(fork.label, "")
        expectNoDifference(join.label, "")
        expectNoDifference(fork.width, 70)
        expectNoDifference(fork.height, 7)
        expectNoDifference(join.width, 70)
        expectNoDifference(join.height, 7)

        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("data-shape=\"fork\""))
        XCTAssertTrue(svg.contains("data-shape=\"join\""))
        XCTAssertTrue(svg.contains("stroke=\"none\""))
    }

    func testStateDirectivesReachModelAndScaleLayoutWidth() async throws {
        let source = """
        stateDiagram-v2
          scale 350 width
          hide empty description
          [*] --> Idle
        """

        let graph = try await MermaidRenderer.parse(source)
        guard case .stateDiagram(let stateGraph) = graph.payload else {
            return XCTFail("Expected a state diagram")
        }
        expectNoDifference(stateGraph.stateConfig.scaleWidth, 350)
        expectNoDifference(stateGraph.stateConfig.hideEmptyDescription, true)

        let positioned = try await MermaidRenderer.layout(source)
        expectNoDifference(positioned.width, 350)
    }

    func testHideEmptyDescriptionSuppressesEmptyDescriptionCompartmentForStateModel() throws {
        let node = original_src_types.MermaidNode(
            id: "OnlyTitle",
            label: "Only title",
            shape: .rectWithTitle,
            descriptions: ["Only title"]
        )

        let visibleGraph = MermaidGraph(payload: .stateDiagram(original_src_types.MermaidGraph(
            direction: .TB,
            nodesInOrder: [("OnlyTitle", node)],
            edges: []
        )))

        var hiddenConfig = original_src_types.StateConfig()
        hiddenConfig.hideEmptyDescription = true
        let hiddenGraph = MermaidGraph(payload: .stateDiagram(original_src_types.MermaidGraph(
            direction: .TB,
            nodesInOrder: [("OnlyTitle", node)],
            edges: [],
            stateConfig: hiddenConfig
        )))

        let visibleNode = try XCTUnwrap(try layoutGraphSync(visibleGraph).flowchartNodes?.first)
        let hiddenNode = try XCTUnwrap(try layoutGraphSync(hiddenGraph).flowchartNodes?.first)
        XCTAssertGreaterThan(visibleNode.height, hiddenNode.height)
    }

    func testStateAsAliasAndLegacyChoiceSyntaxMatchMermaidParserFixtures() async throws {
        let source = """
        stateDiagram-v2
          state "as" as as
          state if_state [[choice]]
          as --> if_state
        """

        let positioned = try await MermaidRenderer.layout(source)
        let nodes = Dictionary(uniqueKeysWithValues: (positioned.flowchartNodes ?? []).map { ($0.id, $0) })
        expectNoDifference(nodes["as"]?.label, "as")
        expectNoDifference(nodes["if_state"]?.shape, "choice")
    }

    func testStateAccessibilityDirectivesRenderSvgTitleAndDesc() async throws {
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

    // MARK: - Phase 1: Concurrent Regions & Composite Rendering

    func testConcurrentRegionsSplitCompositeIntoSubdocuments() async throws {
        let source = """
        stateDiagram-v2
          state Active {
            [*] --> A
            A --> B
            --
            [*] --> C
            C --> D
          }
        """

        let graph = try await MermaidRenderer.parse(source)
        guard case .stateDiagram(let stateGraph) = graph.payload else {
            return XCTFail("Expected state diagram")
        }
        // Should have the Active composite with region children
        let activeSub = stateGraph.subgraphs.first
        XCTAssertNotNil(activeSub)
        XCTAssertFalse(activeSub!.children.isEmpty, "Concurrent regions should create child subgraphs")

        _ = try await MermaidRenderer.layout(source)
        let svg = try await MermaidRenderer.renderSVG(source: source)
        // No raw divider nodes in SVG output
        XCTAssertFalse(svg.contains("_divider_"), "Divider IDs should not appear in SVG")
        // Region subgraphs should exist as groups
        XCTAssertTrue(svg.contains("Active_region_0") || svg.contains("Active_region"))
    }

    func testCompositeStateRendersRoundedWithTitleAndClusterClasses() async throws {
        let source = """
        stateDiagram-v2
          [*] --> Idle
          state Processing {
            parse --> validate
          }
          Idle --> Processing
          Processing --> [*]
        """

        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("statediagram-cluster"), "Composite should have statediagram-cluster class")
        XCTAssertTrue(svg.contains("data-id=\"Processing\""), "Composite should have id attribute")
    }

    func testNestedCompositeAlternatesClusterAltClass() async throws {
        let source = """
        stateDiagram-v2
          state Outer {
            [*] --> A
            state Inner {
              [*] --> B
            }
          }
        """

        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("statediagram-cluster"), "At least one cluster class should be present")
        // Outer composite at depth 0 is not alt, inner at depth 1 is alt
        XCTAssertTrue(svg.contains("statediagram-cluster-alt"), "Nested composite should have alt class")
    }

    func testConcurrentRegionParsesWithoutDividerInSvg() async throws {
        let source = """
        stateDiagram-v2
          state Composite {
            [*] --> State1
            State1 --> State2
            --
            [*] --> State3
          }
        """

        let positioned = try await MermaidRenderer.layout(source)
        // No divider nodes in positioned output
        let dividerNode = positioned.flowchartNodes?.first { $0.id.hasPrefix("_divider") }
        XCTAssertNil(dividerNode, "Divider nodes should be stripped after concurrent region restructuring")

        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("State1"))
        XCTAssertTrue(svg.contains("State3"))
    }

    // MARK: - Phase 2: Multi-Class, CSS Classes, Note Colors, Security

    func testMultipleClassStatementsAccumulateOnStateNode() async throws {
        let source = """
        stateDiagram-v2
          classDef highlight fill:#f9f
          classDef subdued fill:#eee
          class Active highlight
          class Active subdued
          [*] --> Active
        """

        let graph = try await MermaidRenderer.parse(source)
        guard case .stateDiagram(let stateGraph) = graph.payload else {
            return XCTFail("Expected state diagram")
        }
        let assignments = stateGraph.classAssignments["Active"] ?? []
        XCTAssertTrue(assignments.contains("highlight"))
        XCTAssertTrue(assignments.contains("subdued"))
        XCTAssertEqual(assignments.count, 2, "Should accumulate both classes")
    }

    func testSvgContainsStatediagramStateClass() async throws {
        let source = """
        stateDiagram-v2
          [*] --> Idle
          Idle --> Active
        """

        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("statediagram-state"), "State nodes should have statediagram-state class")
    }

    func testSvgContainsTransitionClassOnEdges() async throws {
        let source = """
        stateDiagram-v2
          [*] --> Idle
        """

        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("class=\"edge transition"), "Edges should have transition class")
    }

    func testSvgContainsStatediagramNoteClass() async throws {
        let source = """
        stateDiagram-v2
          State1
          note right of State1 : Test note
        """

        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("statediagram-note"), "Notes should have statediagram-note class")
    }

    func testSvgContainsNoteEdgeClass() async throws {
        let source = """
        stateDiagram-v2
          State1
          note left of State1 : Test note
        """

        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("note-edge"), "Note edges should have note-edge class")
    }

    func testNoteUsesThemeColors() async throws {
        let source = """
        stateDiagram-v2
          State1
          note right of State1 : Test
        """

        let svg = try await MermaidRenderer.renderSVG(source: source)
        XCTAssertTrue(svg.contains("_note-bkg"), "Note should use note background color variable")
        XCTAssertTrue(svg.contains("_note-border"), "Note should use note border color variable")
    }

    func testSandboxSecurityLevelPersistsOnStateConfig() throws {
        var config = original_src_types.StateConfig()
        config.securityLevel = "sandbox"
        let graph = try parseMermaid("stateDiagram-v2\n  [*] --> Idle", stateConfig: config)
        guard case .stateDiagram(let parsed) = graph.payload else {
            return XCTFail("Expected state diagram")
        }
        XCTAssertEqual(parsed.stateConfig.securityLevel, "sandbox")
    }

    func testDangerousUrlBlockedInStateClickParse() async throws {
        let source = """
        stateDiagram-v2
          [*] --> A
          click A href "javascript:alert(1)" "bad"
        """

        let graph = try await MermaidRenderer.parse(source)
        guard case .stateDiagram(let parsed) = graph.payload else {
            return XCTFail("Expected state diagram")
        }
        XCTAssertNil(parsed.nodeInteractions["A"], "Dangerous URL should be blocked")
    }
}
