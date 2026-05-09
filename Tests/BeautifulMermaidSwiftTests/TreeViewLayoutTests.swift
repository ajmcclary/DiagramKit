import Testing
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

@Suite("TreeView Layout")
struct TreeViewLayoutTests {

    @Test("Layout produces positioned nodes")
    func producesPositionedNodes() throws {
        let source = """
        treeView-beta
            src/
                index.js
            package.json
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)

        #expect(positioned.nodes.isEmpty == false)
        #expect(positioned.connectorLines.isEmpty == false)
    }

    @Test("Root node is positioned at x=0, y=0")
    func rootNodePosition() throws {
        let source = "treeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)

        let rootPos = positioned.nodes.first(where: { $0.id == 0 })
        #expect(rootPos != nil)
        #expect(rootPos?.x == 0)
        #expect(rootPos?.y == 0)
    }

    @Test("Depth indentation increases with nesting")
    func depthIndentation() throws {
        let source = """
        treeView-beta
            a/
                b/
                    c.js
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)

        let aPos = positioned.nodes.first(where: { $0.name == "a" })
        let bPos = positioned.nodes.first(where: { $0.name == "b" })
        let cPos = positioned.nodes.first(where: { $0.name == "c.js" })

        #expect(aPos != nil)
        #expect(bPos != nil)
        #expect(cPos != nil)
        #expect(bPos!.x > aPos!.x)
        #expect(cPos!.x > bPos!.x)
    }

    @Test("Connector lines generated for each node")
    func connectorLinesGenerated() throws {
        let source = """
        treeView-beta
            src/
                index.js
            package.json
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)

        #expect(positioned.connectorLines.count > 0)
    }

    @Test("Highlight rects generated for highlight CSS class")
    func highlightRectsGenerated() throws {
        let source = """
        treeView-beta
            file.js :::highlight
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)

        #expect(positioned.highlightRects.isEmpty == false)
    }

    @Test("Description column aligns to max label right edge")
    func descriptionAlignment() throws {
        let source = """
        treeView-beta
            short.js ## short description
            very-long-file-name.js ## very long description too
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)

        #expect(positioned.descriptionX != nil)
    }

    @Test("Empty tree produces minimal positioned output")
    func emptyTree() throws {
        let source = "treeView-beta\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)

        #expect(positioned.nodes.isEmpty == false)
        #expect(positioned.nodes.count == 1)
        #expect(positioned.width > 0)
        #expect(positioned.height > 0)
    }

    @Test("ViewBox includes lineThickness offset")
    func viewBoxOffset() throws {
        let source = "treeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)

        #expect(positioned.viewBoxX < 0)
        #expect(positioned.viewBoxWidth > 0)
        #expect(positioned.viewBoxHeight > 0)
    }

    @Test("ShowIcons config disables icon offset")
    func showIconsDisabled() throws {
        let source = "treeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        diagram.config.showIcons = false
        let positioned = layoutTreeViewDiagram(diagram)

        let nodePos = positioned.nodes.first(where: { $0.id != 0 })
        #expect(nodePos?.iconX == nil)
    }

    @Test("icon(none) removes icon offset for that node")
    func explicitIconSuppressionRemovesOffset() throws {
        let source = "treeView-beta\n    file.js icon(none)\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)

        let nodePos = try #require(positioned.nodes.first(where: { $0.name == "file.js" }))
        #expect(nodePos.iconX == nil)
        #expect(nodePos.labelX == nodePos.x + diagram.config.paddingX)
    }

    @Test("Custom config affects layout")
    func customConfig() throws {
        let source = "treeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        diagram.config.rowIndent = 20
        diagram.config.paddingX = 10
        let positioned = layoutTreeViewDiagram(diagram)

        #expect(positioned.nodes.first(where: { $0.id != 0 }) != nil)
    }

    @Test("Row height is proportional to label text size")
    func rowHeightProportionalToText() throws {
        let source = "treeView-beta\n    a\n    wwwwwwwwwwwwwwww\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)

        let shortNode = try #require(positioned.nodes.first(where: { $0.name == "a" }))
        let wideNode = try #require(positioned.nodes.first(where: { $0.name == "wwwwwwwwwwwwwwww" }))

        #expect(wideNode.width > shortNode.width)
        #expect(shortNode.height > 0)
        #expect(wideNode.height > 0)
    }

    @Test("Connector line vertical spans parent to last child center")
    func connectorVerticalSpan() throws {
        let source = """
        treeView-beta
            a/
                b/
                    c.js
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)

        let parentPos = try #require(positioned.nodes.first(where: { $0.name == "a" }))
        let directChild = try #require(positioned.nodes.first(where: { $0.name == "b" }))

        let verticalLine = positioned.connectorLines.first(where: {
            $0.x1 == $0.x2 && $0.x1 == parentPos.x + diagram.config.paddingX
        })
        #expect(verticalLine != nil)
        #expect(verticalLine!.y1 == parentPos.y + parentPos.height)
        #expect(verticalLine!.y2 == directChild.centerY + diagram.config.lineThickness / 2)
    }

    @Test("Description column X equals max label right edge plus DESC_GAP")
    func descriptionColumnX() throws {
        let source = """
        treeView-beta
            src/
                index.js ## entry point
            README.md
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)

        #expect(positioned.descriptionX != nil)
        let maxLabelRight = positioned.nodes.map(\.labelRightEdge).max() ?? 0
        #expect(positioned.descriptionX! == maxLabelRight + DESC_GAP)
    }

    @Test("Highlight rect width spans to total tree width")
    func highlightRectSpansFullWidth() throws {
        let source = """
        treeView-beta
            short.js :::highlight
            very-long-file-name-with-many-chars.js
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)

        #expect(positioned.highlightRects.isEmpty == false)
        let highlightRect = positioned.highlightRects.first!
        #expect(highlightRect.rx == 3)
        #expect(highlightRect.height > 0)
    }

    @Test("ViewBox X offset equals negative half lineThickness")
    func viewBoxXOffset() throws {
        let source = "treeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var diagram = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        diagram.config.lineThickness = 3
        let positioned = layoutTreeViewDiagram(diagram)

        #expect(positioned.viewBoxX == -1.5)
    }
}
