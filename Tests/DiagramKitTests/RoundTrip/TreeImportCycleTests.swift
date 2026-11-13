import Foundation
import Testing
import DiagramKit
import DiagramKitModel
import DiagramKitExport

// D2 and DOT tree-view / mindmap importers build a tree from an edge list
// that is not known to be a tree, and the matching exporters used node
// names as ids, so an ordinary tree with a repeated name exported as a
// cycle that overflowed the stack on re-import.

private func treeShape(_ node: TreeViewNode) -> String {
    node.children.isEmpty ? node.name : "\(node.name)(\(node.children.map(treeShape).joined(separator: ",")))"
}

private func mindmapShape(_ node: MindmapNode) -> String {
    node.children.isEmpty ? node.descr : "\(node.descr)(\(node.children.map(mindmapShape).joined(separator: ",")))"
}

@Suite("Tree importers and exporters with cycles and repeated names")
struct TreeImportCycleTests {

    @Test("a cyclic D2 / DOT tree imports with a diagnostic instead of overflowing", arguments: [
        ("# diagramkit:family=treeView\nr -> a\na -> b\nb -> a\n", DiagramFormatID.d2),
        ("# diagramkit:family=mindmap\nr -> a\na -> b\nb -> a\n", .d2),
        ("# diagramkit:family=treeView\ndigraph G { r -> a; a -> b; b -> a; }\n", .graphviz),
        ("# diagramkit:family=mindmap\ndigraph G { r -> a; a -> b; b -> a; }\n", .graphviz),
        ("# diagramkit:family=treeView\nr -> r\n", .d2),
    ])
    func cyclicImport(source: String, format: DiagramFormatID) throws {
        let result = try DiagramPipeline.parseImportResult(source, sourceFormat: format)
        switch result.document.payload {
        case .treeView, .mindmap:
            #expect(result.diagnostics.contains { $0.message.contains("cycle") }, "\(result.diagnostics)")
        default:
            break // fell back to flowchart: no tree was built
        }
        _ = try DiagramPipeline.renderSVG(source: source, sourceFormat: format)
    }

    @Test("a diamond ladder stops at the node budget", arguments: [DiagramFormatID.d2])
    func diamondLadder(format: DiagramFormatID) throws {
        var lines = ["# diagramkit:family=treeView"]
        for i in 0..<40 {
            lines.append("n\(i) -> a\(i)")
            lines.append("n\(i) -> b\(i)")
            lines.append("a\(i) -> n\(i + 1)")
            lines.append("b\(i) -> n\(i + 1)")
        }
        let result = try DiagramPipeline.parseImportResult(lines.joined(separator: "\n"), sourceFormat: format)
        guard case .treeView(let tree) = result.document.payload else { Issue.record("not a tree view"); return }
        #expect(tree.nodes.count <= 10_001)
        #expect(result.diagnostics.contains { $0.message.contains("more than") })
    }

    @Test("a tree with repeated names survives export and re-import", arguments: [DiagramFormatID.d2, .graphviz])
    func repeatedTreeNames(format: DiagramFormatID) throws {
        let source = "treeView-beta\n  src\n    src\n      index.ts\n    lib\n      index.ts\n"
        let original = try DiagramPipeline.parse(source)
        guard case .treeView(let before) = original.payload else { Issue.record("not a tree view"); return }
        let exported = try DiagramExportLoader.export(original, to: format, registry: DiagramPipeline.defaultExportRegistry)
        let reparsed = try DiagramPipeline.parse(exported.source, as: format)
        guard case .treeView(let after) = reparsed.payload else { Issue.record("not a tree view: \(exported.source)"); return }
        // A single tree under Mermaid's synthetic `/` container exports as
        // that one tree (pre-existing convention).
        let expected = before.root.name == "/" && before.root.children.count == 1 ? before.root.children[0] : before.root
        #expect(treeShape(after.root) == treeShape(expected), "\(exported.source)")
    }

    @Test("a mindmap with repeated ids survives export and re-import", arguments: [DiagramFormatID.d2, .graphviz])
    func repeatedMindmapIDs(format: DiagramFormatID) throws {
        let original = try DiagramPipeline.parse("mindmap\n  root((Top))\n    A\n      A\n    B\n      A\n")
        guard case .mindmap(let before) = original.payload, let beforeRoot = before.root else {
            Issue.record("not a mindmap"); return
        }
        let exported = try DiagramExportLoader.export(original, to: format, registry: DiagramPipeline.defaultExportRegistry)
        let reparsed = try DiagramPipeline.parse(exported.source, as: format)
        guard case .mindmap(let after) = reparsed.payload, let afterRoot = after.root else {
            Issue.record("not a mindmap: \(exported.source)"); return
        }
        #expect(mindmapShape(afterRoot) == mindmapShape(beforeRoot), "\(exported.source)")
    }
}
