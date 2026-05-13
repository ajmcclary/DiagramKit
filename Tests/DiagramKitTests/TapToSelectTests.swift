#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import XCTest
import DiagramKit
import DiagramKitModel
@testable import DiagramPlayground

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
@MainActor
final class TapToSelectTests: XCTestCase {

    override func setUp() async throws {
        DiagramEngine.bootstrap()
    }

    func test_setSelectionWritesIntoEditor() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\nA --> B\n"))
        try await waitForEditor(store: store)

        let selection = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        store.setSelection(selection)
        XCTAssertEqual(store.editor?.selection?.elementID, "node:A")

        store.setSelection(nil)
        XCTAssertNil(store.editor?.selection)
    }

    func test_handleTapWithoutLookupIsNoop() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\nA --> B\n"))
        try await waitForEditor(store: store)
        // boundsLookup intentionally nil
        store.handleTapAt(viewPoint: CGPoint(x: 50, y: 50), viewSize: CGSize(width: 200, height: 200))
        XCTAssertNil(store.editor?.selection)
    }

    func test_handleTapHittingNodeSetsSelection() async throws {
        // Use a real parse + layout to get a populated DiagramBoundsLookup.
        // DiagramBoundsLookup.Entry is private, so we cannot synthesize one
        // directly — we drive the real pipeline and tap at the actual node bounds.
        let source = "flowchart TD\nA[Start] --> B[End]\n"
        let graph = try await DiagramEngine.layout(source)
        let lookup = graph.lookup
        let store = LiveEditorStore(state: LiveEditorState(source: source))
        try await waitForEditor(store: store)
        store.boundsLookup = lookup
        store.diagramBounds = CGRect(x: 0, y: 0, width: graph.width, height: graph.height)
        store.state.zoomScale = 1
        store.state.panOffset = .zero

        let aSelection = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        let aBounds = try XCTUnwrap(lookup.bounds(of: aSelection))
        let viewSize = CGSize(width: graph.width + 200, height: graph.height + 200)
        // Tap at the geometric centre of node A in view-coords, accounting for
        // the centering offset that PreviewCanvas applies.
        let centerX = (viewSize.width - graph.width) / 2 + CGFloat(aBounds.minX + aBounds.width / 2)
        let centerY = (viewSize.height - graph.height) / 2 + CGFloat(aBounds.minY + aBounds.height / 2)

        store.handleTapAt(viewPoint: CGPoint(x: centerX, y: centerY), viewSize: viewSize)
        XCTAssertEqual(store.editor?.selection?.elementID, "node:A")
    }

    func test_handleTapMissingAnyElementClearsSelection() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\nA --> B\n"))
        try await waitForEditor(store: store)
        store.boundsLookup = DiagramBoundsLookup.empty(diagramType: .flowchart)
        store.editor?.selection = DiagramSelection(diagramType: .flowchart, elementID: "node:A")

        store.handleTapAt(viewPoint: .zero, viewSize: CGSize(width: 200, height: 200))
        XCTAssertNil(store.editor?.selection)
    }

    private func waitForEditor(store: LiveEditorStore, timeout: TimeInterval = 5) async throws {
        let start = Date()
        while store.editor == nil {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("editor never populated within \(timeout)s")
                return
            }
            try await Task.sleep(nanoseconds: 25_000_000)
            store.didCompleteRender(parseError: nil, diagramBounds: .zero)
        }
    }
}
#endif
