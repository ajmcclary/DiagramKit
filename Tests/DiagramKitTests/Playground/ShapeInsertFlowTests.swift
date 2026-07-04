//
//  ShapeInsertFlowTests.swift
//  DiagramKitTests
//
//  Visual editor plan 2 — catalog insert flow: next-free-id
//  generation and insert → select → label-edit stage.
//

#if canImport(CoreGraphics)
import CoreGraphics
import XCTest
import DiagramKit
import DiagramKitInteractive
import DiagramKitModel
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class ShapeInsertFlowTests: XCTestCase {

    override func setUp() async throws {
        DiagramEngine.bootstrap()
    }

    /// Drive the render path until `store.editor` becomes non-nil.
    /// Mirrors LiveEditorStoreEditorLifecycleTests: in production the
    /// editor is seeded by DiagramView's prepareCompletion; in tests we
    /// call didCompleteRender directly to simulate a successful render.
    private func waitForEditor(store: LiveEditorStore, timeout: TimeInterval = 5) async throws {
        let start = Date()
        while store.editor == nil {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("editor never became available")
                return
            }
            try await Task.sleep(nanoseconds: 25_000_000)
            store.didCompleteRender(parseError: nil, diagramBounds: .zero)
        }
    }

    func test_nextIDSkipsExistingNodeIDs() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  n1 --> n2\n"))
        try await waitForEditor(store: store)
        XCTAssertEqual(store.nextFlowchartNodeID(), "n3")
    }

    func test_nextIDStartsAtOne() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)
        XCTAssertEqual(store.nextFlowchartNodeID(), "n1")
    }

    func test_nextIDNilWithoutEditor() {
        let store = LiveEditorStore(state: LiveEditorState(source: ""))
        XCTAssertNil(store.nextFlowchartNodeID())
    }

    func test_insertShapeAddsSelectsAndOpensLabelEditor() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)

        await store.insertShapeFromCatalog(alias: "cloud")

        guard case .flowchart(let graph) = store.editor?.document.payload else {
            XCTFail("payload is not a flowchart"); return
        }
        let node = graph.nodesInOrder.first { $0.id == "n1" }
        XCTAssertNotNil(node)
        XCTAssertEqual(node?.node.shape, .cloud)
        XCTAssertEqual(node?.node.label, "New node")
        XCTAssertEqual(store.editor?.selection?.elementID, "node:n1")
        XCTAssertEqual(store.state.visualStage, .labelEdited)
        XCTAssertTrue(store.state.source.contains("n1"))
    }

    func test_insertShapeNoOpsWithoutEditor() async {
        let store = LiveEditorStore(state: LiveEditorState(source: ""))
        await store.insertShapeFromCatalog(alias: "cloud")
        XCTAssertEqual(store.state.visualStage, .idle)
    }
}
#endif
