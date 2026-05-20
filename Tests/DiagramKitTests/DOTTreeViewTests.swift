import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
@testable import DiagramKitGraphviz

@Suite("DOT treeView import/export")
struct DOTTreeViewTests {

    @Test("Family marker routes to treeView payload")
    func familyMarkerForcesTreeView() throws {
        let source = """
        digraph G {
          # diagramkit:family=treeView
          # diagramkit:tree-root=root
          root [label="root"];
          a [label="A"];
          root -> a;
        }
        """
        let result = try GraphvizImporter().parse(source)
        guard case .treeView = result.document.payload else {
            Issue.record("expected treeView payload, got \(result.document.payload)")
            return
        }
    }

    @Test("Round-trips tree structure preserving names")
    func roundTripsStructure() throws {
        let leaf = TreeViewNode(id: 1, level: 1, name: "A", nodeType: .file)
        let root = TreeViewNode(id: 0, level: 0, name: "root", nodeType: .directory, children: [leaf])
        let tree = TreeViewDiagram(root: root, nodes: [root, leaf])

        let document = DiagramDocument(payload: .treeView(tree))
        let result = try DOTExporter().export(document)
        #expect(result.source.contains("# diagramkit:family=treeView"))
        #expect(result.source.contains("# diagramkit:tree-root=root"))

        let parsed = try GraphvizImporter().parse(result.source)
        guard case .treeView(let parsedTree) = parsed.document.payload else {
            Issue.record("expected treeView payload"); return
        }
        #expect(parsedTree.root.children.map(\.name) == ["A"])
    }
}
