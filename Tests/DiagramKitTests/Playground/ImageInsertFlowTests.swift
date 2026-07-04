//
//  ImageInsertFlowTests.swift
//  DiagramKitTests
//
//  Visual editor plan 5 — image sheet insert flow.
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
final class ImageInsertFlowTests: XCTestCase {

    override func setUp() async throws {
        DiagramEngine.bootstrap()
    }

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

    func test_insertImageFromSheetInsertsConfiguredNode() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)
        store.openImageSheet()
        XCTAssertTrue(store.isImageSheetOpen)

        await store.insertImageFromSheet(
            urlString: "https://example.com/pic.png", width: 200, height: 150, title: "Pic"
        )

        XCTAssertFalse(store.isImageSheetOpen)
        guard case .flowchart(let graph) = store.editor?.document.payload else {
            XCTFail("not a flowchart"); return
        }
        let node = graph.nodesInOrder.first { $0.id == "n1" }?.node
        XCTAssertEqual(node?.shape, .imageSquare)
        XCTAssertEqual(node?.properties?.img, "https://example.com/pic.png")
        XCTAssertEqual(node?.properties?.w, 200)
        XCTAssertEqual(node?.label, "Pic")
        XCTAssertEqual(store.editor?.selection?.elementID, "node:n1")
        XCTAssertEqual(store.state.visualStage, .nodeSelected)
    }

    func test_invalidURLKeepsSheetOpenAndRecordsError() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)
        store.openImageSheet()

        await store.insertImageFromSheet(urlString: "ftp://nope", width: 120, height: 90, title: nil)

        XCTAssertTrue(store.isImageSheetOpen, "sheet stays open so the user can fix the URL")
        XCTAssertNotNil(store.lastMutationError)
        guard case .flowchart(let graph) = store.editor?.document.payload else {
            XCTFail("not a flowchart"); return
        }
        XCTAssertEqual(graph.nodesInOrder.count, 2, "no node inserted on invalid URL")
    }
}
#endif
