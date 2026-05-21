import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKitPlantUML

@Suite("PlantUMLTreeViewExporter — convention bridging")
struct PlantUMLTreeViewExporterConventionTests {

    @Test("real-root payload emits `* root` (existing behavior)")
    func realRootEmits() throws {
        let leaf = TreeViewNode(id: 2, level: 1, name: "leaf", nodeType: .file)
        let root = TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .directory, children: [leaf])
        let diagram = TreeViewDiagram(root: root, nodes: [root, leaf])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        let src = result.source
        #expect(src.contains("@startwbs"))
        #expect(src.contains("* alpha"))
        #expect(src.contains("** leaf"))
        #expect(result.diagnostics.allSatisfy { $0.category != .slotUnsupported })
    }

    @Test("synthetic-root with single child emits child as `*` losslessly")
    func syntheticSingleChild() throws {
        let leaf = TreeViewNode(id: 2, level: 1, name: "leaf", nodeType: .file)
        let only = TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .directory, children: [leaf])
        let synthetic = TreeViewNode(
            id: 0, level: -1, name: "/", nodeType: .directory, children: [only]
        )
        let diagram = TreeViewDiagram(root: synthetic, nodes: [synthetic, only, leaf])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        let src = result.source
        #expect(src.contains("* alpha"))
        #expect(src.contains("** leaf"))
        #expect(!src.contains("* /"))
        // Lossless — no slotUnsupported diagnostic.
        #expect(result.diagnostics.allSatisfy { $0.category != .slotUnsupported })
    }

    @Test("synthetic-root with multi children emits first as `*`, drops siblings with diagnostic")
    func syntheticMultiChildDrop() throws {
        let a = TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .file)
        let b = TreeViewNode(id: 2, level: 0, name: "beta", nodeType: .file)
        let c = TreeViewNode(id: 3, level: 0, name: "gamma", nodeType: .file)
        let synthetic = TreeViewNode(
            id: 0, level: -1, name: "/", nodeType: .directory, children: [a, b, c]
        )
        let diagram = TreeViewDiagram(root: synthetic, nodes: [synthetic, a, b, c])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        let src = result.source

        #expect(src.contains("* alpha"), "first child becomes the root")
        #expect(!src.contains("* beta"), "second child must NOT appear as a root")
        #expect(!src.contains("* gamma"), "third child must NOT appear as a root")
        #expect(!src.contains("* /"))

        // Two dropped siblings → two .slotUnsupported diagnostics.
        let drops = result.diagnostics.filter { $0.category == .slotUnsupported }
        #expect(drops.count == 2)
        #expect(drops.allSatisfy { $0.severity == .unsupported })
        let messages = drops.map(\.message)
        #expect(messages.contains { $0.contains("beta") })
        #expect(messages.contains { $0.contains("gamma") })
    }

    @Test("synthetic-root with zero children emits empty @startwbs/@endwbs")
    func syntheticZeroChildren() throws {
        let synthetic = TreeViewNode(
            id: 0, level: -1, name: "/", nodeType: .directory, children: []
        )
        let diagram = TreeViewDiagram(root: synthetic, nodes: [synthetic])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        let src = result.source
        #expect(src.contains("@startwbs"))
        #expect(src.contains("@endwbs"))
        #expect(!src.contains("* /"))
        #expect(!src.contains("\n* "))
    }
}
