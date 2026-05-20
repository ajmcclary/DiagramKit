import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
@testable import DiagramKitD2

@Suite("D2 treeView import/export")
struct D2TreeViewTests {

    @Test("Family marker routes to treeView payload")
    func familyMarkerForcesTreeView() throws {
        let source = """
        # diagramkit:family=treeView
        # diagramkit:tree-root=root
        root: "Root"
        a: "A"
        root -> a
        """
        let result = try D2Importer().parse(source)
        guard case .treeView = result.document.payload else {
            Issue.record("expected treeView payload, got \(result.document.payload)")
            return
        }
    }

    @Test("Round-trips tree structure preserving names and parent/child links")
    func roundTripsStructure() throws {
        let leafA = TreeViewNode(id: 1, level: 1, name: "A", nodeType: .file)
        let leafB = TreeViewNode(id: 2, level: 1, name: "B", nodeType: .file)
        let root = TreeViewNode(id: 0, level: 0, name: "root", nodeType: .directory, children: [leafA, leafB])
        let tree = TreeViewDiagram(root: root, nodes: [root, leafA, leafB])

        let document = DiagramDocument(payload: .treeView(tree))
        let result = try D2Exporter().export(document)
        #expect(result.source.contains("# diagramkit:family=treeView"))
        #expect(result.source.contains("# diagramkit:tree-root=root"))

        let parsed = try D2Importer().parse(result.source)
        guard case .treeView(let parsedTree) = parsed.document.payload else {
            Issue.record("expected treeView payload"); return
        }
        #expect(parsedTree.root.name == "root")
        #expect(parsedTree.root.children.map(\.name) == ["A", "B"])
    }
}
