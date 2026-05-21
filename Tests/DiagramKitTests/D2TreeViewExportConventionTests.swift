import Testing
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2 treeView exporter — convention bridging")
struct D2TreeViewExportConventionTests {

    @Test("real-root payload emits root verbatim (existing behavior)")
    func realRootVerbatim() throws {
        let leaf = TreeViewNode(id: 2, level: 1, name: "leaf", nodeType: .file)
        let root = TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .directory, children: [leaf])
        let diagram = TreeViewDiagram(root: root, nodes: [root, leaf])
        let result = try D2TreeViewExport.emit(diagram, title: nil)
        let src = result.source
        #expect(src.contains("# diagramkit:family=treeView"))
        #expect(src.contains("# diagramkit:tree-root=alpha"))
        #expect(src.contains("alpha: \"alpha\""))
        #expect(src.contains("alpha -> leaf"))
        #expect(!src.contains("/: \"/\""), "synthetic / must never appear")
    }

    @Test("synthetic-root payload emits forest with first-child marker")
    func syntheticRootForest() throws {
        let a = TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .file)
        let b = TreeViewNode(id: 2, level: 0, name: "beta", nodeType: .file)
        let synthetic = TreeViewNode(
            id: 0, level: -1, name: "/", nodeType: .directory, children: [a, b]
        )
        let diagram = TreeViewDiagram(root: synthetic, nodes: [synthetic, a, b])
        let result = try D2TreeViewExport.emit(diagram, title: nil)
        let src = result.source

        #expect(src.contains("# diagramkit:family=treeView"))
        #expect(src.contains("# diagramkit:tree-root=alpha"), "marker pins the first child")
        #expect(src.contains("alpha: \"alpha\""))
        #expect(src.contains("beta: \"beta\""))
        #expect(!src.contains("/: \"/\""), "synthetic / must never appear")
        // Forest emission: NO `alpha -> beta` edge, the children are separate roots.
        #expect(!src.contains("alpha -> beta"))
    }
}
