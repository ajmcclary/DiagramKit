#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import XCTest
import DiagramKit
import DiagramKitInteractive
import DiagramKitModel
@testable import DiagramPlayground

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
@MainActor
final class LiveEditorStoreEditorLifecycleTests: XCTestCase {

    override func setUp() async throws {
        DiagramEngine.bootstrap()
    }

    func test_editorIsNilForEmptySource() {
        let store = LiveEditorStore(state: LiveEditorState(source: ""))
        XCTAssertNil(store.editor)
    }

    func test_editorIsRebuiltAfterValidFlowchartSource() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: ""))
        store.setSource("flowchart TD\nA --> B\n", origin: .system)

        try await waitForEditor(store: store)

        XCTAssertNotNil(store.editor)
        XCTAssertEqual(store.editor?.document.type, .flowchart)
        XCTAssertEqual(store.editor?.preferredExportFormat, store.state.sourceFormat.formatID)
    }

    func test_editorRetainsPreviousValueOnParseError() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\nA --> B\n"))
        try await waitForEditor(store: store)
        let firstEditor = try XCTUnwrap(store.editor)

        store.setSource("garbage that cannot parse", origin: .system)
        try await waitForRender(store: store)

        XCTAssertTrue(store.editor === firstEditor)
        XCTAssertNotNil(store.parseError)
    }

    func test_performSetLabelUpdatesSourceAndPreservesSelection() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\nA --> B\n"))
        try await waitForEditor(store: store)
        let selection = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        store.setSelection(selection)

        try await store.performMutation(.setLabel(of: selection, to: "Renamed"))
        try await waitForRenderTick(store: store)

        XCTAssertTrue(store.state.source.contains("Renamed"))
        XCTAssertEqual(store.editor?.selection?.elementID, "node:A")
    }

    func test_toggleInspectorFlipsState() {
        let store = LiveEditorStore(state: LiveEditorState())
        XCTAssertFalse(store.state.inspectorOpen)
        store.toggleInspector()
        XCTAssertTrue(store.state.inspectorOpen)
        store.toggleInspector()
        XCTAssertFalse(store.state.inspectorOpen)
    }

    // MARK: - Helpers

    /// Drive the render path until `store.editor` becomes non-nil or the
    /// helper times out.
    fileprivate func waitForEditor(store: LiveEditorStore, timeout: TimeInterval = 5) async throws {
        let start = Date()
        while store.editor == nil {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("editor never populated within \(timeout)s")
                return
            }
            try await Task.sleep(nanoseconds: 25_000_000)
            // Force-feed the render lifecycle: in production this is driven by
            // DiagramView's prepareCompletion. In tests we call the entry point
            // directly with a zero bounds, simulating a successful render.
            store.didCompleteRender(parseError: nil, diagramBounds: .zero)
        }
    }

    /// Drive the render path one tick so the store observes the most recent
    /// state transition.
    fileprivate func waitForRender(store: LiveEditorStore, timeout: TimeInterval = 1) async throws {
        try await Task.sleep(nanoseconds: 50_000_000)
        store.didCompleteRender(parseError: NSError(domain: "test", code: 1), diagramBounds: .zero)
    }

    /// Tick a successful render so re-seed runs after a mutation.
    fileprivate func waitForRenderTick(store: LiveEditorStore, timeout: TimeInterval = 1) async throws {
        try await Task.sleep(nanoseconds: 50_000_000)
        store.didCompleteRender(parseError: nil, diagramBounds: .zero)
    }
}
#endif
