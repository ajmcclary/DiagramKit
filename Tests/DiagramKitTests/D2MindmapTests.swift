import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
@testable import DiagramKitD2

@Suite("D2 mindmap import/export")
struct D2MindmapTests {

    @Test("Family marker routes to mindmap payload")
    func familyMarkerForcesMindmap() throws {
        let source = """
        # diagramkit:family=mindmap
        # diagramkit:tree-root=root
        root: "Root"
        a: "A"
        b: "B"
        root -> a
        root -> b
        """
        let result = try D2Importer().parse(source)
        guard case .mindmap = result.document.payload else {
            Issue.record("expected mindmap payload, got \(result.document.payload)")
            return
        }
    }

    @Test("Exporter round-trips bang shape via mindmap-icon marker")
    func bangIconMarker() throws {
        let child = MindmapNode(id: 1, nodeId: "child", level: 1, descr: "Child", type: .default)
        let root = MindmapNode(id: 0, nodeId: "root", level: 0, descr: "Root", type: .bang, children: [child], isRoot: true)
        let mindmap = MindmapDiagram(root: root, nodes: [root, child])
        let document = DiagramDocument(payload: .mindmap(mindmap))
        let result = try D2Exporter().export(document)
        #expect(result.source.contains("# diagramkit:family=mindmap"))
        #expect(result.source.contains("# diagramkit:mindmap-icon=root,bang"))

        let parsed = try D2Importer().parse(result.source)
        guard case .mindmap(let parsedMindmap) = parsed.document.payload else {
            Issue.record("expected mindmap payload on round-trip")
            return
        }
        let parsedRoot = try #require(parsedMindmap.root)
        #expect(parsedRoot.type == .bang)
        #expect(parsedRoot.nodeId == "root")
    }
}
