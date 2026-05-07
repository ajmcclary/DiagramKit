import Testing
@testable import BeautifulMermaid

@Suite("TreeView SVG")
struct TreeViewSvgTests {

    @Test("SVG contains root tree-view class")
    func svgContainsTreeViewClass() throws {
        let source = "treeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("class=\"tree-view\""))
    }

    @Test("SVG contains label class")
    func svgContainsLabelClass() throws {
        let source = "treeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("treeView-node-label"))
    }

    @Test("SVG contains directory class for directories")
    func svgContainsDirClass() throws {
        let source = "treeView-beta\n    src/\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("treeView-node-dir"))
    }

    @Test("SVG contains icon defs")
    func svgContainsIconDefs() throws {
        let source = "treeView-beta\n    file.js\n    App.tsx\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("<defs>"))
        #expect(svg.contains("tv-icon-test-"))
    }

    @Test("SVG contains icon use elements")
    func svgContainsIconUse() throws {
        let source = "treeView-beta\n    App.tsx\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("<use"))
        #expect(svg.contains("treeView-node-icon"))
    }

    @Test("SVG contains connector line class")
    func svgContainsConnectorLine() throws {
        let source = "treeView-beta\n    src/\n        index.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("treeView-node-line"))
    }

    @Test("SVG contains highlight background class")
    func svgContainsHighlightBg() throws {
        let source = "treeView-beta\n    file.js :::highlight\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("treeView-highlight-bg"))
    }

    @Test("SVG contains description elements")
    func svgContainsDescription() throws {
        let source = "treeView-beta\n    file.js ## entry point\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("treeView-node-description"))
    }

    @Test("SVG contains viewBox attribute")
    func svgContainsViewBox() throws {
        let source = "treeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("viewBox="))
    }

    @Test("SVG contains style block")
    func svgContainsStyleBlock() throws {
        let source = "treeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("<style>"))
        #expect(svg.contains("treeView-node-label"))
    }

    @Test("XML escaping in labels and descriptions")
    func xmlEscaping() throws {
        let source = "treeView-beta\n    \"file<test>.js\"\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("file&lt;test&gt;.js"))
    }

    @Test("Accessibility title and desc")
    func accessibilityElements() throws {
        let source = """
        treeView-beta
        accTitle: Test tree
        accDescr: A test tree diagram
            file.js
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("<title>Test tree</title>"))
        #expect(svg.contains("<desc>A test tree diagram</desc>"))
    }
}
