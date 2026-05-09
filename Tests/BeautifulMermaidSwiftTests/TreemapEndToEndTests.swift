import Foundation
import Testing
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

@Suite("Treemap End-to-End")
struct TreemapEndToEndTests {

    @Test("Parse to SVG pipeline through renderMermaidSVG")
    func parseToSvg() throws {
        let source = """
        treemap
        "Category A"
            "Item 1": 10
            "Item 2": 20
        """

        let preprocessed = _preprocessMermaidSource(source)
        let rawLines = preprocessed.source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var diagram = try parseTreemapDiagram(rawLines, frontmatter: preprocessed.frontmatter)
        if let cfg = preprocessed.frontmatter?.treemapConfig { diagram.config = cfg }

        let positioned = layoutTreemapDiagram(diagram)
        let colors = DiagramColors(bg: "#ffffff", fg: "#000000")
        let diagramId = UUID().uuidString
        let svg = renderTreemapSvg(positioned, diagramId: diagramId, colors, "Inter", false)

        #expect(svg.hasPrefix("<svg"))
        #expect(svg.contains("Category A"))
        #expect(svg.contains("Item 1"))
        #expect(svg.contains("Item 2"))
    }

    @Test("Parse to SVG with frontmatter config")
    func parseToSvgWithFrontmatter() throws {
        let source = """
        ---
        config:
          treemap:
            showValues: false
        ---
        treemap
        "Cat"
            "Item": 10
        """

        let preprocessed = _preprocessMermaidSource(source)
        let rawLines = preprocessed.source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var diagram = try parseTreemapDiagram(rawLines, frontmatter: preprocessed.frontmatter)
        if let cfg = preprocessed.frontmatter?.treemapConfig { diagram.config = cfg }

        let positioned = layoutTreemapDiagram(diagram)
        #expect(positioned.config.showValues == false)
    }

    @Test("Parse to SVG with frontmatter theme")
    func parseToSvgWithTheme() throws {
        let source = """
        ---
        config:
          theme: dark
        ---
        treemap
        "Cat"
            "Item": 10
        """

        let preprocessed = _preprocessMermaidSource(source)
        let rawLines = preprocessed.source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var diagram = try parseTreemapDiagram(rawLines, frontmatter: preprocessed.frontmatter)
        if let theme = preprocessed.frontmatter?.theme { diagram.themeName = theme }

        #expect(diagram.themeName == "dark")
    }

    @Test("MermaidParser routes treemap")
    func parserRoutesTreemap() async throws {
        let source = """
        treemap
        "A": 10
        """
        let graph = try await MermaidRenderer.parse(source)
        #expect(graph.type == .treemap)
    }

    @Test("GraphLayout routes treemap")
    func layoutRoutesTreemap() async throws {
        let source = """
        treemap
        "A": 10
        """
        let positioned = try await MermaidRenderer.layout(source)
        #expect(positioned.diagram.type == .treemap)
    }
}
