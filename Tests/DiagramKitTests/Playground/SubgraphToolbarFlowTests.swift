//
//  SubgraphToolbarFlowTests.swift
//  DiagramKitTests
//
//  Visual editor plan 3 — store-side subgraph flows: empty-insert
//  prompt, rename prompt, membership query, marquee delete.
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
final class SubgraphToolbarFlowTests: XCTestCase {

    override func setUp() async throws {
        DiagramEngine.bootstrap()
    }

    private let groupedSource = """
    graph TD
      subgraph g1 [Group One]
        A --> B
      end
      C
    """

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

    private func makeStore() async throws -> LiveEditorStore {
        let store = LiveEditorStore(state: LiveEditorState(source: groupedSource))
        try await waitForEditor(store: store)
        return store
    }

    func test_commitEmptySubgraphPromptInsertsSubgraph() async throws {
        let store = try await makeStore()
        store.openEmptySubgraphPrompt()
        XCTAssertEqual(store.subgraphTitlePrompt, .insertEmpty)
        await store.commitTitlePrompt(title: "Fresh")
        XCTAssertNil(store.subgraphTitlePrompt)
        XCTAssertTrue(store.flowchartSubgraphs.contains { $0.label == "Fresh" })
    }

    func test_commitRenamePromptRenames() async throws {
        let store = try await makeStore()
        store.openRenamePrompt(subgraphID: "g1")
        guard case .rename(let id, let current) = store.subgraphTitlePrompt else {
            XCTFail("expected rename prompt"); return
        }
        XCTAssertEqual(id, "g1")
        XCTAssertEqual(current, "Group One")
        await store.commitTitlePrompt(title: "Renamed")
        XCTAssertTrue(store.flowchartSubgraphs.contains { $0.label == "Renamed" })
    }

    func test_subgraphContainingNode() async throws {
        let store = try await makeStore()
        XCTAssertEqual(store.subgraphID(containing: "A"), "g1")
        XCTAssertNil(store.subgraphID(containing: "C"))
    }

    func test_deleteMarqueeSelectionDeletesAllInOneUndoStep() async throws {
        let store = try await makeStore()
        store.setMarqueeSelection(["node:A", "node:C"])
        await store.deleteMarqueeSelection()

        guard case .flowchart(let model) = store.editor?.document.payload else {
            XCTFail("not a flowchart"); return
        }
        XCTAssertEqual(model.nodesInOrder.map(\.id), ["B"])
        XCTAssertTrue(store.state.marqueeSelection.isEmpty)

        store.editor?.undoManager.undo()
        guard case .flowchart(let restored) = store.editor?.document.payload else {
            XCTFail("not a flowchart"); return
        }
        XCTAssertEqual(restored.nodesInOrder.count, 3)
    }
}
#endif
