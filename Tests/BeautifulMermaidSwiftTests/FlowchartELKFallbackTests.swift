import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// flowchart-elk header is parsed as a renderer hint, but falls back to dagre layout.
/// This matches Mermaid JS behavior without the external @mermaid-js/layout-elk package.
final class FlowchartELKFallbackTests: XCTestCase {

    func testFlowchartElkParsesWithoutError() async throws {
        let source = "flowchart-elk LR\n  A[Start] --> B[End]"
        let graph = try await MermaidRenderer.parse(source)
        XCTAssertEqual(graph.type, .flowchart)
    }

    func testFlowchartElkRendersSVG() async throws {
        let source = "flowchart-elk LR\n  A[Start] --> B[End]"
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<svg"), "flowchart-elk should produce valid SVG with dagre fallback")
        XCTAssertTrue(svg.contains("A"), "Node A should be present")
        XCTAssertTrue(svg.contains("B"), "Node B should be present")
    }

    func testFlowchartElkWithMetadata() async throws {
        let source = """
        flowchart-elk TD
          A[Process]@{ shape: bang } --> B[Result]
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<svg"))
    }

    func testFlowchartElkWithoutDirectionDefaultsToTD() async throws {
        let source = "flowchart-elk\n  A --> B"
        let graph = try await MermaidRenderer.parse(source)
        XCTAssertEqual(graph.type, .flowchart)
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<svg"))
    }
}
