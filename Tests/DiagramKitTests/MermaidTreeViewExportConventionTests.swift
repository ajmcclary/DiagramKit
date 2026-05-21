import Testing
import DiagramKitModel
@testable import DiagramKitMermaid

@Suite("MermaidTreeViewExport convention bridging")
struct MermaidTreeViewExportConventionTests {

    @Test("synthetic-root payload emits children only (existing behavior)")
    func syntheticRootEmitsChildrenOnly() throws {
        let leaf = TreeViewNode(id: 2, level: 1, name: "leaf", nodeType: .file)
        let alpha = TreeViewNode(
            id: 1, level: 0, name: "alpha", nodeType: .directory, children: [leaf]
        )
        let synthetic = TreeViewNode(
            id: 0, level: -1, name: "/", nodeType: .directory, children: [alpha]
        )
        let diagram = TreeViewDiagram(root: synthetic, nodes: [synthetic, alpha, leaf])
        let result = try MermaidTreeViewExport.emit(diagram)
        let src = result.source
        #expect(src.contains("treeView-beta"))
        #expect(src.contains("alpha/"), "alpha appears in source")
        #expect(src.contains("leaf"), "leaf appears in source")
        // Synthetic `/` must never appear as a standalone token line.
        let lines = src.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        #expect(!lines.contains("/"), "synthetic / must never appear as a line")
        #expect(!lines.contains("/ /"))
    }

    @Test("real-root payload emits root then descendants")
    func realRootEmitsRoot() throws {
        // Simulates a D2/DOT/PlantUML-imported payload: root at level 0.
        let leaf = TreeViewNode(id: 2, level: 1, name: "leaf", nodeType: .file)
        let root = TreeViewNode(
            id: 1, level: 0, name: "alpha", nodeType: .directory, children: [leaf]
        )
        let diagram = TreeViewDiagram(root: root, nodes: [root, leaf])
        let result = try MermaidTreeViewExport.emit(diagram)
        let src = result.source
        #expect(src.contains("treeView-beta"))
        // Real root MUST appear — current bug drops it.
        #expect(src.contains("alpha/"), "real root must be present")
        #expect(src.contains("leaf"), "descendant must be present")
        // Indent must be relative — leaf must come AFTER alpha and be
        // indented more deeply.
        let alphaLine = src.range(of: "alpha/")?.lowerBound
        let leafLine = src.range(of: "leaf")?.lowerBound
        if let a = alphaLine, let l = leafLine { #expect(a < l) }
    }
}
