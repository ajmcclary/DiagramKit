//
//  IconBrowserFlowTests.swift
//  DiagramKitTests
//
//  Visual editor plan 4 — icon catalog integrity + browser insert flow.
//

#if canImport(CoreGraphics)
import CoreGraphics
import XCTest
import DiagramKit
import DiagramKitCommon
import DiagramKitInteractive
import DiagramKitModel
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class IconBrowserFlowTests: XCTestCase {

    override func setUp() async throws {
        DiagramEngine.bootstrap()
    }

    func test_catalogCoversTheFontAwesomeMap() {
        XCTAssertEqual(IconCatalog.all.count, FontAwesomeMap.faToSF.count)
        for item in IconCatalog.all {
            XCTAssertEqual(FontAwesomeMap.faToSF[item.faName], item.sfSymbol)
        }
        // Sorted for stable browsing.
        XCTAssertEqual(IconCatalog.all.map(\.faName), IconCatalog.all.map(\.faName).sorted())
    }

    func test_searchMatchesFAName() {
        XCTAssertTrue(IconCatalog.search("user").contains { $0.faName == "user" })
        XCTAssertTrue(IconCatalog.search("USER").contains { $0.faName == "user" })
        XCTAssertEqual(IconCatalog.search("").count, IconCatalog.all.count)
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

    func test_insertIconFromBrowserInsertsConfiguredNode() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)

        await store.insertIconFromBrowser(faName: "user")

        guard case .flowchart(let graph) = store.editor?.document.payload else {
            XCTFail("not a flowchart"); return
        }
        let node = graph.nodesInOrder.first { $0.id == "n1" }?.node
        XCTAssertEqual(node?.shape, .iconCircle)
        XCTAssertEqual(node?.properties?.icon, "fa:user")
        XCTAssertEqual(node?.properties?.h, 48)
        XCTAssertEqual(store.editor?.selection?.elementID, "node:n1")
        XCTAssertEqual(store.state.visualStage, .labelEdited)
    }
}
#endif
