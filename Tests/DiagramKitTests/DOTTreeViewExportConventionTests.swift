import Testing
import DiagramKitModel
@testable import DiagramKitGraphviz

@Suite("DOT treeView exporter — convention bridging")
struct DOTTreeViewExportConventionTests {

    @Test("real-root payload emits root verbatim (existing behavior)")
    func realRootVerbatim() throws {
        let leaf = TreeViewNode(id: 2, level: 1, name: "leaf", nodeType: .file)
        let root = TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .directory, children: [leaf])
        let diagram = TreeViewDiagram(root: root, nodes: [root, leaf])
        let result = try DOTTreeViewExport.emit(diagram, title: nil)
        let src = result.source
        #expect(src.contains("# diagramkit:family=treeView"))
        #expect(src.contains("# diagramkit:tree-root=alpha"))
        #expect(src.contains("alpha [label=\"alpha\"];"))
        #expect(src.contains("alpha -> leaf;"))
        #expect(!src.contains("[label=\"/\"]"), "synthetic / must never appear")
    }

    @Test("synthetic-root payload emits forest with first-child marker")
    func syntheticRootForest() throws {
        let a = TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .file)
        let b = TreeViewNode(id: 2, level: 0, name: "beta", nodeType: .file)
        let synthetic = TreeViewNode(
            id: 0, level: -1, name: "/", nodeType: .directory, children: [a, b]
        )
        let diagram = TreeViewDiagram(root: synthetic, nodes: [synthetic, a, b])
        let result = try DOTTreeViewExport.emit(diagram, title: nil)
        let src = result.source

        #expect(src.contains("# diagramkit:family=treeView"))
        #expect(src.contains("# diagramkit:tree-root=alpha"), "marker pins the first child")
        #expect(src.contains("alpha [label=\"alpha\"];"))
        #expect(src.contains("beta [label=\"beta\"];"))
        #expect(!src.contains("[label=\"/\"]"), "synthetic / must never appear")
        #expect(!src.contains("alpha -> beta;"))
    }
}
