import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("TreeView SVG")
struct TreeViewSvgTests {

    @Test("SVG contains root tree-view class")
    func svgContainsTreeViewClass() throws {
        let source = "treeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("class=\"tree-view\""))
    }

    @Test("SVG contains label class")
    func svgContainsLabelClass() throws {
        let source = "treeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("treeView-node-label"))
    }

    @Test("SVG contains directory class for directories")
    func svgContainsDirClass() throws {
        let source = "treeView-beta\n    src/\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("treeView-node-dir"))
    }

    @Test("SVG contains icon defs")
    func svgContainsIconDefs() throws {
        let source = "treeView-beta\n    file.js\n    App.tsx\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("<defs>"))
        #expect(svg.contains("tv-icon-test-"))
    }

    @Test("SVG contains icon use elements")
    func svgContainsIconUse() throws {
        let source = "treeView-beta\n    App.tsx\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("<use"))
        #expect(svg.contains("treeView-node-icon"))
    }

    @Test("SVG contains connector line class")
    func svgContainsConnectorLine() throws {
        let source = "treeView-beta\n    src/\n        index.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("treeView-node-line"))
    }

    @Test("SVG contains highlight background class")
    func svgContainsHighlightBg() throws {
        let source = "treeView-beta\n    file.js :::highlight\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("treeView-highlight-bg"))
    }

    @Test("SVG contains description elements")
    func svgContainsDescription() throws {
        let source = "treeView-beta\n    file.js ## entry point\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("treeView-node-description"))
    }

    @Test("SVG contains viewBox attribute")
    func svgContainsViewBox() throws {
        let source = "treeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("viewBox="))
    }

    @Test("SVG contains style block")
    func svgContainsStyleBlock() throws {
        let source = "treeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("<style>"))
        #expect(svg.contains("treeView-node-label"))
    }

    @Test("XML escaping in labels and descriptions")
    func xmlEscaping() throws {
        let source = "treeView-beta\n    \"file<test>.js\"\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
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
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("<title>Test tree</title>"))
        #expect(svg.contains("<desc>A test tree diagram</desc>"))
    }

    @Test("Highlight rect precedes icon and text in group (z-order)")
    func highlightRectPrecedesContent() throws {
        let source = """
        treeView-beta
            App.tsx :::highlight icon(react) ## main component
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        let rectIdx = svg.range(of: "<rect class=\"treeView-highlight-bg\"")?.lowerBound
        let useIdx = svg.range(of: "<use xlink:href=\"#tv-icon-test-react\"")?.lowerBound
        let appTsxIdx = svg.range(of: ">App.tsx<")?.lowerBound

        #expect(rectIdx != nil)
        #expect(useIdx != nil)
        #expect(appTsxIdx != nil)
        #expect(rectIdx! < useIdx!)
        #expect(rectIdx! < appTsxIdx!)
    }

    @Test("Highlight rect uses correct rx and class")
    func highlightRectAttributes() throws {
        let source = """
        treeView-beta
            file.js :::highlight
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("rx=\"3"))
        #expect(svg.contains("class=\"treeView-highlight-bg\""))
    }

    @Test("Non-highlight nodes have no highlight rect element")
    func noHighlightRectForNormalNodes() throws {
        let source = """
        treeView-beta
            normal.js
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(!svg.contains("<rect class=\"treeView-highlight-bg\""))
    }

    @Test("Cypress fixture: complex treeView with multi-level nesting")
    func cypressComplexTreeView() throws {
        let source = """
        treeView-beta
            "root"
                "folder1"
                    "file1.js"
                    "file2.ts"
                "folder2"
                    "file3.spec.ts"
                    "folder3"
                        "file4.ts"
                        "file5.ts"
                        "folder4"
                            "file6.ts"
                "file7.ts"
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("file1.js"))
        #expect(svg.contains("file6.ts"))
        #expect(svg.contains("file7.ts"))
        #expect(svg.contains("treeView-node-line"))
        #expect(svg.contains("treeView-node-dir"))
    }

    @Test("Cypress fixture: multiple roots with quoted labels")
    func cypressMultipleRoots() throws {
        let source = """
        treeView-beta
            "folder1"
                "file1.js"
                "file2.ts"
            "folder2"
                "file3.spec.ts"
                "folder3"
                    "file4.ts"
                    "file5.ts"
                    "folder4"
                        "file6.ts"
            "file7.ts"
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("folder1"))
        #expect(svg.contains("folder2"))
        #expect(svg.contains("file7.ts"))
    }

    @Test("Cypress fixture: custom config frontmatter applies theme in SVG")
    func cypressCustomConfigFrontmatter() async throws {
        let source = """
        ---
        config:
          treeView:
              rowIndent: 80
              lineThickness: 3
          themeVariables:
              treeView:
                  labelFontSize: '20px'
                  labelColor: '#FF0000'
                  lineColor: '#00FF00'
        ---
        treeView-beta
              "folder1"
                  "file1.js"
                  "file2.ts"
              "folder2"
                  "file3.spec.ts"
                  "folder3"
                      "file4.ts"
                      "file5.ts"
                      "folder4"
                          "file6.ts"
              "file7.ts"
        """

        let svg = try await DiagramEngine.renderSVG(source: source)

        #expect(svg.contains("font-size:20px"))
        #expect(svg.contains("fill:#FF0000"))
        #expect(svg.contains("stroke:#00FF00"))
    }

    @Test("Cypress fixture: bare labels with icons produce icon defs and uses")
    func cypressBareLabelsWithIcons() throws {
        let source = """
        treeView-beta
            my-project/
                src/
                    components/
                        Button.tsx
                        Header.tsx
                    App.tsx
                    index.js
                .gitignore
                package.json
                README.md
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("tv-icon-test-react"))
        #expect(svg.contains("tv-icon-test-folder"))
        #expect(svg.contains("tv-icon-test-javascript"))
        #expect(svg.contains("tv-icon-test-git"))
        #expect(svg.contains("tv-icon-test-json"))
        #expect(svg.contains("tv-icon-test-markdown"))
    }

    @Test("Cypress fixture: icon() overrides render explicit icon")
    func cypressIconOverrides() throws {
        let source = """
        treeView-beta
            data/
                model.bin icon(database)
                weights.h5 icon(database)
            src/
                index.js
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("tv-icon-test-database"))
    }

    @Test("Cypress fixture: combined annotations produce all elements")
    func cypressCombinedAnnotations() throws {
        let source = """
        treeView-beta
            my-project/
                src/
                    App.tsx :::highlight icon(react) ## main component
                    index.js ## entry point
                    styles.css
                .env ## environment variables
                Dockerfile
                package.json
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let svg = renderTreeViewSvg(positioned, diagramId: "test", font: "Inter")

        #expect(svg.contains("treeView-highlight-bg"))
        #expect(svg.contains("tv-icon-test-react"))
        #expect(svg.contains("main component"))
        #expect(svg.contains("entry point"))
        #expect(svg.contains("environment variables"))
        #expect(svg.contains("treeView-node-description"))
    }
}
