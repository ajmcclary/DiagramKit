import Testing
@testable import DiagramKitPlantUML

@Suite struct PlantUMLWBSParserTests {
    @Test func parsesSingleRoot() {
        let body = "* root"
        let tree = PlantUMLWBSParser().parse(body)
        #expect(tree.root?.label == "root")
        #expect(tree.root?.depth == 1)
        #expect(tree.root?.children.isEmpty == true)
    }

    @Test func parsesHierarchy() {
        let body = """
        * root
        ** child1
        *** grandchild
        ** child2
        """
        let tree = PlantUMLWBSParser().parse(body)
        #expect(tree.root?.label == "root")
        #expect(tree.root?.children.count == 2)
        #expect(tree.root?.children[0].label == "child1")
        #expect(tree.root?.children[0].children.count == 1)
        #expect(tree.root?.children[0].children[0].label == "grandchild")
        #expect(tree.root?.children[1].label == "child2")
    }

    @Test func extractsShapeVariant() {
        let body = "* root <<box>>"
        let tree = PlantUMLWBSParser().parse(body)
        #expect(tree.root?.label == "root")
        #expect(tree.root?.shape == "box")
    }

    @Test func extractsColorSuffix() {
        let body = "* root #LightBlue"
        let tree = PlantUMLWBSParser().parse(body)
        #expect(tree.root?.label == "root")
        #expect(tree.root?.color == "LightBlue")
    }

    @Test func skipsCommentsAndBlankLines() {
        let body = """

        ' a comment
        * root
        ' another
        ** child
        """
        let tree = PlantUMLWBSParser().parse(body)
        #expect(tree.root?.label == "root")
        #expect(tree.root?.children.count == 1)
    }

    @Test func extractsTitle() {
        let body = """
        title My Tree
        * root
        """
        let tree = PlantUMLWBSParser().parse(body)
        #expect(tree.title == "My Tree")
        #expect(tree.root?.label == "root")
    }

    @Test func capturesMultipleRoots() {
        let body = """
        * root1
        * root2
        """
        let tree = PlantUMLWBSParser().parse(body)
        #expect(tree.root?.label == "root1")
        #expect(tree.unsupportedLines.isEmpty == false)
    }
}
