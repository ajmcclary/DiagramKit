//
//  BidirectionalSelectionTests.swift
//  DiagramKitTests
//
//  Phase 2 / Task 2.3 — exercises the heuristic SourceMap +
//  store.hoverEditorLine / store.hoverPreviewNode pair. The actual
//  pointer-hover wiring inside NativeCodeEditor lands in a later
//  phase; this suite locks in the data-layer contract today.
//

import XCTest
@testable import DiagramPlayground

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class BidirectionalSelectionTests: XCTestCase {

    // MARK: - SourceMap

    func test_sourceMapExtractsMermaidIdentifiersPerLine() {
        let source = """
        flowchart TD
          A[Start]
          B[Middle]
          A --> B
        """
        let map = SourceMap(source: source, format: .mermaid)
        XCTAssertNil(map.lineToNode[0]) // diagram-type skipped
        XCTAssertEqual(map.lineToNode[1], "A")
        XCTAssertEqual(map.lineToNode[2], "B")
        // The arrow line resolves to "A" (the source side of the edge).
        XCTAssertEqual(map.lineToNode[3], "A")
        XCTAssertEqual(map.nodeToLine["A"], 1)
        XCTAssertEqual(map.nodeToLine["B"], 2)
    }

    func test_sourceMapSkipsBlankAndCommentLines() {
        let source = """
        flowchart TD
          %% comment line

          A[Start]
        """
        let map = SourceMap(source: source, format: .mermaid)
        XCTAssertNil(map.lineToNode[0])
        XCTAssertNil(map.lineToNode[1])
        XCTAssertNil(map.lineToNode[2])
        XCTAssertEqual(map.lineToNode[3], "A")
    }

    // MARK: - Store hover plumbing

    @MainActor
    func test_hoverEditorLineSetsBiSelNodeFromMap() {
        let store = LiveEditorStore()
        store.setSource("flowchart TD\n  A[Start]\n  B[Middle]", origin: .system)
        store.hoverEditorLine(1)
        XCTAssertEqual(store.state.biSelLine, 1)
        XCTAssertEqual(store.state.biSelNode, "A")
    }

    @MainActor
    func test_hoverPreviewNodeSetsBiSelLineFromMap() {
        let store = LiveEditorStore()
        store.setSource("flowchart TD\n  A[Start]\n  B[Middle]", origin: .system)
        store.hoverPreviewNode("B")
        XCTAssertEqual(store.state.biSelNode, "B")
        XCTAssertEqual(store.state.biSelLine, 2)
    }

    @MainActor
    func test_hoverNilClearsBothFields() {
        let store = LiveEditorStore()
        store.setSource("flowchart TD\n  A[Start]", origin: .system)
        store.hoverEditorLine(1)
        store.hoverEditorLine(nil)
        XCTAssertNil(store.state.biSelLine)
        XCTAssertNil(store.state.biSelNode)
    }
}
