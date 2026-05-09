import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class FlowchartVisualDiffTests: XCTestCase {

    // MARK: - Structural SVG assertions

    func testSimpleGraphTDProducesSVGWithNodes() async throws {
        let svg = try await renderMermaidSVG(
            "graph TD\n  A[Start] --> B[End]",
            RenderOptions()
        )
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("class=\"node\""), "Should have node elements")
        XCTAssertTrue(svg.contains("A"), "Node A should be present")
        XCTAssertTrue(svg.contains("B"), "Node B should be present")
        XCTAssertTrue(svg.contains("marker-end"), "Should have arrow markers")
    }

    func testCircleArrowhead() async throws {
        let svg = try await renderMermaidSVG(
            "graph LR\n  A --o B",
            RenderOptions()
        )
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("marker-end"), "Should contain arrow markers")
    }

    func testCrossArrowhead() async throws {
        let svg = try await renderMermaidSVG(
            "graph LR\n  A --x B",
            RenderOptions()
        )
        XCTAssertTrue(svg.contains("<svg"))
    }

    func testInvisibleEdge() async throws {
        let svg = try await renderMermaidSVG(
            "graph LR\n  A ~~~ B\n  A --> C",
            RenderOptions()
        )
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("C"), "Visible edge target should be present")
        XCTAssertTrue(svg.contains("B"), "Invisible edge target B should still be present (layout-only)")
    }

    func testEdgeWithTextLabel() async throws {
        let svg = try await renderMermaidSVG(
            "graph TD\n  A --|text| B",
            RenderOptions()
        )
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("text"), "Edge label text should be present")
    }

    func testChainedEdgesWithAmpersand() async throws {
        let svg = try await renderMermaidSVG(
            "graph TD\n  A & B --> C",
            RenderOptions()
        )
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("A"))
        XCTAssertTrue(svg.contains("B"))
        XCTAssertTrue(svg.contains("C"))
    }

    func testMetadataShape() async throws {
        let source = """
        graph TD
          A@{ shape: bang } --> B
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<svg"))
    }

    func testClickHrefInSVG() async throws {
        let svg = try await renderMermaidSVG(
            "graph LR\n  A[Link] --> B\n  click A href \"https://safe.com\"",
            RenderOptions()
        )
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("xlink:href=\"https://safe.com\""), "Should contain link")
    }

    func testAccessibilityTitleAndDescription() async throws {
        let source = """
        graph TD
          accTitle: My Diagram
          accDescr: A test diagram
          A --> B
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<title>My Diagram</title>"))
        XCTAssertTrue(svg.contains("<desc>A test diagram</desc>"))
    }

    func testSubgraphElements() async throws {
        let source = """
        graph TD
          subgraph Group [My Group]
            A --> B
          end
          C --> A
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("My Group"), "Subgraph label should be present")
        XCTAssertTrue(svg.contains("class=\"subgraph\""), "Should have subgraph elements")
    }

    func testFlowchartWithConfigFrontmatter() async throws {
        let source = """
        ---
        config:
          flowchart:
            curve: basis
        ---
        graph TD
          A --> B
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<svg"))
    }

    func testAllHeaderVariantsProduceSVG() async throws {
        let variants: [(source: String, name: String)] = [
            ("graph LR\n  A --> B", "graph LR"),
            ("flowchart BT\n  A --> B", "flowchart BT"),
            ("flowchart-elk LR\n  A --> B", "flowchart-elk LR"),
        ]
        for (source, _) in variants {
            let svg = try await renderMermaidSVG(source, RenderOptions())
            XCTAssertTrue(svg.contains("<svg"))
        }
    }
}
