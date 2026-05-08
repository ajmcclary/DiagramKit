import XCTest
@testable import BeautifulMermaid

final class MindmapRendererTests: XCTestCase {
    private struct PlaygroundDiagram: Decodable {
        let category: String
        let name: String
        let source: String
    }

    private struct PlaygroundFixture: Decodable {
        let diagrams: [PlaygroundDiagram]
    }

    private static func projectRoot() -> String {
        var url = URL(fileURLWithPath: #file).deletingLastPathComponent()
        while url.path != "/" {
            let package = url.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: package.path) {
                return url.path
            }
            url.deleteLastPathComponent()
        }
        return FileManager.default.currentDirectoryPath
    }

    func test_parseReturnsMindmapPayload() throws {
        let graph = try MermaidParser.parse("mindmap\n  root\n    A")
        guard case .mindmap = graph.payload else {
            XCTFail("Expected .mindmap payload, got \(graph.payload)")
            return
        }
    }

    func test_pipelineParseLayoutRender_defaultLayout() async throws {
        // No frontmatter — default tidy-tree layout takes effect.
        let source = "mindmap\n  root((mindmap))\n    A\n    B"
        let svg = try await renderMermaidSVG(source)
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("mindmapDiagram"))
    }

    func test_renderASCII_throwsNotYetImplemented() {
        XCTAssertThrowsError(try original_src_ascii_index.renderMermaidASCII("mindmap\n  root")) { error in
            guard let bmError = error as? BeautifulMermaidError else {
                XCTFail("Expected BeautifulMermaidError, got \(error)")
                return
            }
            if case .notYetImplemented(let msg) = bmError {
                XCTAssertTrue(msg.contains("Mindmap"))
            } else {
                XCTFail("Expected notYetImplemented, got \(bmError)")
            }
        }
    }

    func test_detectDiagramType_recognizesMindmap() {
        let detected = original_src_ascii_index.detectDiagramType("mindmap\n  root")
        XCTAssertEqual(detected, "mindmap")
    }

    func test_emptyParsedGraph_hasEmptyValues() {
        let empty = MindmapDiagram.empty
        XCTAssertNil(empty.root)
        XCTAssertEqual(empty.nodes.count, 0)
    }

    func test_PositionedMindmapDiagram_empty() {
        let empty = PositionedMindmapDiagram.empty
        XCTAssertEqual(empty.width, 0)
        XCTAssertEqual(empty.height, 0)
        XCTAssertEqual(empty.nodes.count, 0)
    }

    func test_layoutDispatch_usesMindmapLayout() throws {
        // Default layout resolves to tidy-tree; no frontmatter needed.
        let source = "mindmap\n  root\n    A"
        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)
        XCTAssertEqual(positioned.diagram.type, .mindmap)
    }

    func test_playgroundMindmapExamplesRender() async throws {
        let path = (Self.projectRoot() as NSString).appendingPathComponent(
            "Examples/MermaidPlayground/Resources/test-diagrams.json"
        )
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let fixture = try JSONDecoder().decode(PlaygroundFixture.self, from: data)
        let mindmaps = fixture.diagrams.filter { $0.category == "mindmap" }

        XCTAssertEqual(mindmaps.count, 9)
        for diagram in mindmaps {
            let svg = try await renderMermaidSVG(diagram.source)
            XCTAssertTrue(svg.contains("mindmapDiagram"), diagram.name)
        }
    }

    // MARK: - Frontmatter-driven pipeline tests

    func test_pipeline_frontmatterLayoutOverride_tidyTree_renders() async throws {
        // Explicit config.layout: tidy-tree via frontmatter should render
        let source = """
        ---
        config:
          layout: tidy-tree
        ---
        mindmap
          root((mindmap))
            A
            B
        """
        let svg = try await renderMermaidSVG(source)
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("mindmapDiagram"))
        XCTAssertTrue(svg.contains("mindmap-node"), "Should contain mindmap node markup")
    }

    func test_pipeline_frontmatterMindmapLayoutAlgorithm_tidyTree_renders() async throws {
        // Explicit config.mindmap.layoutAlgorithm: tidy-tree via frontmatter should render
        let source = """
        ---
        config:
          mindmap:
            layoutAlgorithm: tidy-tree
        ---
        mindmap
          root((mindmap))
            A
            B
        """
        let svg = try await renderMermaidSVG(source)
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("mindmapDiagram"))
    }

    func test_MermaidGraph_initType() {
        let graph = MermaidGraph(type: .mindmap)
        XCTAssertEqual(graph.type, .mindmap)
    }
}
