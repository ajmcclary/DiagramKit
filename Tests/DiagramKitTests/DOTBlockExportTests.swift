import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKitGraphviz

@Suite("DOTBlockExport")
struct DOTBlockExportTests {

    @Test("Single rectangle node")
    func singleRectangle() throws {
        let block = BlockDiagram(
            rootChildren: ["a"],
            blockDatabase: [
                "root": BlockNode(id: "root", type: .composite, children: ["a"], columns: -1),
                "a":    BlockNode(id: "a", label: "A", type: .square),
            ]
        )
        let result = try DOTBlockExport.emit(block, title: nil)
        #expect(result.source.contains("digraph G {"))
        #expect(result.source.contains("# diagramkit:family=block"))
        #expect(result.source.contains("a [label=\"A\"];"))
    }

    @Test("Composite emits subgraph cluster_<id>")
    func compositeCluster() throws {
        let block = BlockDiagram(
            rootChildren: ["g"],
            blockDatabase: [
                "root": BlockNode(id: "root", type: .composite, children: ["g"], columns: -1),
                "g":    BlockNode(id: "g", label: "G", type: .composite, children: ["a"], columns: 2),
                "a":    BlockNode(id: "a", label: "A", type: .square),
            ]
        )
        let result = try DOTBlockExport.emit(block, title: nil)
        #expect(result.source.contains("subgraph cluster_g {"))
        #expect(result.source.contains("label=\"G\";"))
        #expect(result.source.contains("# diagramkit:block-cols=g,2"))
    }

    @Test("Shape fallback emits marker + diagnostic")
    func shapeFallback() throws {
        let block = BlockDiagram(
            rootChildren: ["a"],
            blockDatabase: [
                "root": BlockNode(id: "root", type: .composite, children: ["a"], columns: -1),
                "a":    BlockNode(id: "a", label: "A", type: .leanLeft),
            ]
        )
        let result = try DOTBlockExport.emit(block, title: nil)
        #expect(result.source.contains("shape=parallelogram"))
        #expect(result.source.contains("# diagramkit:block-shape-fallback=a,lean_left"))
        #expect(result.diagnostics.count == 1)
        #expect(result.diagnostics[0].category == .shapeDowngrade)
    }

    @Test("Edge always emits attrs marker")
    func edgeAttrs() throws {
        let block = BlockDiagram(
            rootChildren: ["a", "b"],
            blockDatabase: [
                "root": BlockNode(id: "root", type: .composite, children: ["a", "b"], columns: -1),
                "a":    BlockNode(id: "a", label: "A", type: .square),
                "b":    BlockNode(id: "b", label: "B", type: .square),
            ],
            edges: [BlockEdge(id: "e0", start: "a", end: "b", label: "calls",
                              thickness: "thick", pattern: "dashed",
                              arrowTypeEnd: "arrow", arrowTypeStart: "arrow_open")]
        )
        let result = try DOTBlockExport.emit(block, title: nil)
        #expect(result.source.contains("a -> b [label=\"calls\"];"))
        #expect(result.source.contains("# diagramkit:block-edge-attrs=0,thick,dashed,arrow_open,arrow"))
    }

    @Test("ClassDef + class apply + acc markers")
    func metadata() throws {
        let block = BlockDiagram(
            rootChildren: ["a"],
            blockDatabase: [
                "root": BlockNode(id: "root", type: .composite, children: ["a"], columns: -1),
                "a":    BlockNode(id: "a", label: "A", type: .square, classes: ["blue"]),
            ],
            classes: ["blue": BlockClassDef(id: "blue", styles: ["fill:#6cf"])],
            accTitle: "Acc title",
            accDescr: "Acc descr"
        )
        let result = try DOTBlockExport.emit(block, title: nil)
        #expect(result.source.contains("# diagramkit:block-classdef=blue,fill:#6cf"))
        #expect(result.source.contains("# diagramkit:block-class-apply=a,blue"))
        #expect(result.source.contains("# diagramkit:block-acc-title=Acc title"))
        #expect(result.source.contains("# diagramkit:block-acc-descr=Acc descr"))
    }
}
