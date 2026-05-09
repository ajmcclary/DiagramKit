import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("Treemap Model")
struct TreemapModelTests {

    @Test("TreemapNode.isLeaf identifies leaf nodes")
    func isLeaf() {
        let leaf = TreemapNode(name: "Item", value: 10)
        #expect(leaf.isLeaf)
        let section = TreemapNode(name: "Section", children: [])
        #expect(!section.isLeaf)
    }

    @Test("TreemapNode.aggregateValue sums children")
    func aggregateValue() {
        let root = TreemapNode(name: "Root", children: [
            TreemapNode(name: "A", children: [], value: nil),
            TreemapNode(name: "B", value: 100)
        ])
        #expect(root.aggregateValue == 100)
    }

    @Test("TreemapDiagramConfig has correct defaults")
    func configDefaults() {
        let config = TreemapDiagramConfig.default
        #expect(config.useMaxWidth == true)
        #expect(config.padding == 10)
        #expect(config.diagramPadding == 8)
        #expect(config.showValues == true)
        #expect(config.nodeWidth == 100)
        #expect(config.nodeHeight == 40)
        #expect(config.borderWidth == 1)
        #expect(config.valueFontSize == 12)
        #expect(config.labelFontSize == 14)
        #expect(config.valueFormat == ",")
    }

    @Test("TreemapClassDef.parseStyleText splits styles")
    func parseStyleText() {
        let (node, text) = TreemapClassDef.parseStyleText("fill:#ff0,color:#333,stroke:#999")
        #expect(node.count >= 2)
        #expect(text.count >= 1)
    }

    @Test("TreemapClassDef.parseStyleText handles escaped commas")
    func escapedCommas() {
        let (_, _) = TreemapClassDef.parseStyleText("fill:url(#grad\\,ient)")
    }

    @Test("TreemapThemeDefaults provides correct defaults")
    func themeDefaults() {
        #expect(TreemapThemeDefaults.defaultCScale.count == 13)
        #expect(TreemapThemeDefaults.defaultCScale[0] == "transparent")
        #expect(TreemapThemeDefaults.defaultCScalePeer.count == 13)
        #expect(TreemapThemeDefaults.defaultCScalePeer[0] == "transparent")
        #expect(TreemapThemeDefaults.defaultCScaleLabel.count == 12)
    }
}
