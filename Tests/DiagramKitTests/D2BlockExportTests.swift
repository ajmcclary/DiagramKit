import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2BlockExporter")
struct D2BlockExportTests {

    @Test("Single rectangle node")
    func singleRectangle() {
        let block = BlockDiagram(
            rootChildren: ["a"],
            blockDatabase: [
                "root": BlockNode(id: "root", type: .composite, children: ["a"], columns: -1),
                "a":    BlockNode(id: "a", label: "A", type: .square),
            ]
        )
        let result = D2BlockExporter.emit(block)
        #expect(result.source.contains("# diagramkit:family=block"))
        #expect(result.source.contains("a: \"A\""))
        #expect(result.diagnostics.isEmpty)
    }

    @Test("Nested composite")
    func nestedComposite() {
        let block = BlockDiagram(
            rootChildren: ["g"],
            blockDatabase: [
                "root": BlockNode(id: "root", type: .composite, children: ["g"], columns: -1),
                "g":    BlockNode(id: "g", label: "G", type: .composite, children: ["a"], columns: 2),
                "a":    BlockNode(id: "a", label: "A", type: .square),
            ]
        )
        let result = D2BlockExporter.emit(block)
        #expect(result.source.contains("g: \"G\" {"))
        #expect(result.source.contains("  a: \"A\""))
        #expect(result.source.contains("}"))
        #expect(result.source.contains("# diagramkit:block-cols=g,2"))
    }

    @Test("Width span emits marker")
    func widthMarker() {
        let block = BlockDiagram(
            rootChildren: ["a"],
            blockDatabase: [
                "root": BlockNode(id: "root", type: .composite, children: ["a"], columns: -1),
                "a":    BlockNode(id: "a", label: "A", type: .square, widthInColumns: 2),
            ]
        )
        let result = D2BlockExporter.emit(block)
        #expect(result.source.contains("# diagramkit:block-width=a,2"))
    }

    @Test("Shape fallback emits marker + diagnostic")
    func shapeFallbackLean() {
        let block = BlockDiagram(
            rootChildren: ["a"],
            blockDatabase: [
                "root": BlockNode(id: "root", type: .composite, children: ["a"], columns: -1),
                "a":    BlockNode(id: "a", label: "A", type: .leanLeft),
            ]
        )
        let result = D2BlockExporter.emit(block)
        #expect(result.source.contains("a.shape: parallelogram"))
        #expect(result.source.contains("# diagramkit:block-shape-fallback=a,lean_left"))
        #expect(result.diagnostics.count == 1)
        let diag = result.diagnostics[0]
        #expect(diag.severity == .warning)
        #expect(diag.category == .shapeDowngrade)
    }

    @Test("Block arrow emits two markers")
    func blockArrowMarkers() {
        let block = BlockDiagram(
            rootChildren: ["arrow1"],
            blockDatabase: [
                "root":   BlockNode(id: "root", type: .composite, children: ["arrow1"], columns: -1),
                "arrow1": BlockNode(
                    id: "arrow1",
                    label: "Sync",
                    type: .blockArrow,
                    directions: [.right, .up]
                ),
            ]
        )
        let result = D2BlockExporter.emit(block)
        #expect(result.source.contains("# diagramkit:block-shape-fallback=arrow1,block_arrow"))
        #expect(result.source.contains("# diagramkit:block-arrow-dir=arrow1,right,up"))
    }

    @Test("Space cell emits marker without node line")
    func spaceMarkerOnly() {
        let block = BlockDiagram(
            rootChildren: ["a", "space_root_1", "b"],
            blockDatabase: [
                "root":         BlockNode(id: "root", type: .composite, children: ["a", "space_root_1", "b"], columns: -1),
                "a":             BlockNode(id: "a", label: "A", type: .square),
                "space_root_1":  BlockNode(id: "space_root_1", type: .space),
                "b":             BlockNode(id: "b", label: "B", type: .square),
            ]
        )
        let result = D2BlockExporter.emit(block)
        #expect(result.source.contains("# diagramkit:block-space=root,1"))
        #expect(!result.source.contains("space_root_1:"))
    }

    @Test("Edge always emits attrs marker")
    func edgeAttrsAlwaysEmitted() {
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
        let result = D2BlockExporter.emit(block)
        #expect(result.source.contains("a -> b: \"calls\""))
        #expect(result.source.contains("# diagramkit:block-edge-attrs=0,thick,dashed,arrow_open,arrow"))
    }

    @Test("ClassDef + class apply emit markers")
    func classDefMarkers() {
        let block = BlockDiagram(
            rootChildren: ["a"],
            blockDatabase: [
                "root": BlockNode(id: "root", type: .composite, children: ["a"], columns: -1),
                "a":    BlockNode(id: "a", label: "A", type: .square, classes: ["blue"]),
            ],
            classes: ["blue": BlockClassDef(id: "blue", styles: ["fill:#6cf", "stroke:#333"])]
        )
        let result = D2BlockExporter.emit(block)
        #expect(result.source.contains("# diagramkit:block-classdef=blue,fill:#6cf;stroke:#333"))
        #expect(result.source.contains("# diagramkit:block-class-apply=a,blue"))
    }

    @Test("Inline style emits marker")
    func inlineStyle() {
        let block = BlockDiagram(
            rootChildren: ["a"],
            blockDatabase: [
                "root": BlockNode(id: "root", type: .composite, children: ["a"], columns: -1),
                "a":    BlockNode(id: "a", label: "A", type: .square, styles: ["fill:#f00"]),
            ]
        )
        let result = D2BlockExporter.emit(block)
        #expect(result.source.contains("# diagramkit:block-style=a,fill:#f00"))
    }

    @Test("Title and accessibility metadata")
    func titleAndAcc() {
        let block = BlockDiagram(
            rootChildren: [],
            accTitle: "Acc title",
            accDescr: "Acc descr"
        )
        let result = D2BlockExporter.emit(block, title: "My title")
        #expect(result.source.contains("title: \"My title\""))
        #expect(result.source.contains("# diagramkit:block-acc-title=Acc title"))
        #expect(result.source.contains("# diagramkit:block-acc-descr=Acc descr"))
    }
}
