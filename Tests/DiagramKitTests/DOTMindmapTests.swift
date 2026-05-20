import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
@testable import DiagramKitGraphviz

@Suite("DOT mindmap import/export")
struct DOTMindmapTests {

    @Test("Family marker routes to mindmap payload")
    func familyMarkerForcesMindmap() throws {
        let source = """
        digraph G {
          # diagramkit:family=mindmap
          # diagramkit:tree-root=root
          root [label="Root"];
          a [label="A"];
          root -> a;
        }
        """
        let result = try GraphvizImporter().parse(source)
        guard case .mindmap = result.document.payload else {
            Issue.record("expected mindmap payload, got \(result.document.payload)")
            return
        }
    }

    @Test("Bang shape round-trips via mindmap-icon marker")
    func bangIconMarker() throws {
        let child = MindmapNode(id: 1, nodeId: "child", level: 1, descr: "Child", type: .default)
        let root = MindmapNode(id: 0, nodeId: "root", level: 0, descr: "Root", type: .bang, children: [child], isRoot: true)
        let mindmap = MindmapDiagram(root: root, nodes: [root, child])
        let document = DiagramDocument(payload: .mindmap(mindmap))
        let result = try DOTExporter().export(document)
        #expect(result.source.contains("# diagramkit:family=mindmap"))
        #expect(result.source.contains("# diagramkit:mindmap-icon=root,bang"))

        let parsed = try GraphvizImporter().parse(result.source)
        guard case .mindmap(let parsedMindmap) = parsed.document.payload else {
            Issue.record("expected mindmap payload"); return
        }
        let parsedRoot = try #require(parsedMindmap.root)
        #expect(parsedRoot.type == .bang)
        #expect(parsedRoot.nodeId == "root")
    }
}
