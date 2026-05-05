import XCTest
import CustomDump
@testable import BeautifulMermaid

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
}
