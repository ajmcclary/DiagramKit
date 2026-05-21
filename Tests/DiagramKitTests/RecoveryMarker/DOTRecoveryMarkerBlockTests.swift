import Testing
@testable import DiagramKitGraphviz

@Suite("DOTRecoveryMarker block cases")
struct DOTRecoveryMarkerBlockTests {

    @Test func emitAndParseCols() {
        let line = DOTRecoveryMarker.emitBlockCols(containerID: "group", columns: 3)
        #expect(line == "# diagramkit:block-cols=group,3")
        #expect(parsed(line) == .blockCols(containerID: "group", columns: 3))
    }

    @Test func emitAndParseWidth() {
        let line = DOTRecoveryMarker.emitBlockWidth(nodeID: "a", widthInColumns: 2)
        #expect(line == "# diagramkit:block-width=a,2")
        #expect(parsed(line) == .blockWidth(nodeID: "a", widthInColumns: 2))
    }

    @Test func emitAndParseShapeFallback() {
        let line = DOTRecoveryMarker.emitBlockShapeFallback(nodeID: "n1", rawValue: "lean_left")
        #expect(line == "# diagramkit:block-shape-fallback=n1,lean_left")
        #expect(parsed(line) == .blockShapeFallback(nodeID: "n1", rawValue: "lean_left"))
    }

    @Test func emitAndParseArrowDir() {
        let line = DOTRecoveryMarker.emitBlockArrowDir(nodeID: "arrow1", directionsCsv: "right,up")
        #expect(line == "# diagramkit:block-arrow-dir=arrow1,right,up")
        #expect(parsed(line) == .blockArrowDir(nodeID: "arrow1", directionsCsv: "right,up"))
    }

    @Test func emitAndParseSpace() {
        let line = DOTRecoveryMarker.emitBlockSpace(parentID: "root", columnIndex: 4)
        #expect(line == "# diagramkit:block-space=root,4")
        #expect(parsed(line) == .blockSpace(parentID: "root", columnIndex: 4))
    }

    @Test func emitAndParseEdgeAttrs() {
        let line = DOTRecoveryMarker.emitBlockEdgeAttrs(
            edgeIndex: 0, thickness: "thick", pattern: "dashed",
            arrowStart: "arrow_open", arrowEnd: "arrow"
        )
        #expect(line == "# diagramkit:block-edge-attrs=0,thick,dashed,arrow_open,arrow")
        #expect(parsed(line) == .blockEdgeAttrs(
            edgeIndex: 0,
            thickness: "thick",
            pattern: "dashed",
            arrowStart: "arrow_open",
            arrowEnd: "arrow"
        ))
    }

    @Test func emitAndParseClassDef() {
        let line = DOTRecoveryMarker.emitBlockClassDef(
            className: "blue",
            stylesCsv: "fill:#6cf;stroke:#333"
        )
        #expect(line == "# diagramkit:block-classdef=blue,fill:#6cf;stroke:#333")
        #expect(parsed(line) == .blockClassDef(className: "blue", stylesCsv: "fill:#6cf;stroke:#333"))
    }

    @Test func emitAndParseClassApply() {
        let line = DOTRecoveryMarker.emitBlockClassApply(nodeID: "A", className: "blue")
        #expect(line == "# diagramkit:block-class-apply=A,blue")
        #expect(parsed(line) == .blockClassApply(nodeID: "A", className: "blue"))
    }

    @Test func emitAndParseStyle() {
        let line = DOTRecoveryMarker.emitBlockStyle(nodeID: "A", stylesCsv: "fill:#f00")
        #expect(line == "# diagramkit:block-style=A,fill:#f00")
        #expect(parsed(line) == .blockStyle(nodeID: "A", stylesCsv: "fill:#f00"))
    }

    @Test func emitAndParseAccTitle() {
        let line = DOTRecoveryMarker.emitBlockAccTitle("My title")
        #expect(line == "# diagramkit:block-acc-title=My title")
        #expect(parsed(line) == .blockAccTitle(text: "My title"))
    }

    @Test func emitAndParseAccDescr() {
        let line = DOTRecoveryMarker.emitBlockAccDescr("Long descr")
        #expect(line == "# diagramkit:block-acc-descr=Long descr")
        #expect(parsed(line) == .blockAccDescr(text: "Long descr"))
    }

    private func parsed(_ line: String) -> DOTRecoveryMarker.Kind? {
        DOTRecoveryMarker.scanner.scan(source: line).markers.first?.kind
    }
}
