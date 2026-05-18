//
//  EditorTabsTests.swift
//  DiagramKitTests
//
//  Phase 2 / Task 2.1 — openTabs / activeTabId state + open/close/activate
//  setters on LiveEditorStore.
//

import XCTest
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
final class EditorTabsTests: XCTestCase {

    func test_defaultStateOpensThreeTabsAndActivatesFirst() {
        let state = LiveEditorState()
        XCTAssertEqual(state.openTabs.count, 3)
        XCTAssertEqual(state.activeTabId, state.openTabs.first)
    }

    func test_codecRoundTripPreservesTabs() throws {
        var state = LiveEditorState()
        state.openTabs = ["a", "b", "c"]
        state.activeTabId = "b"
        let encoded = LiveEditorStateCodec.encode(state)
        let decoded = try LiveEditorStateCodec.decode(encoded)
        XCTAssertEqual(decoded.openTabs, ["a", "b", "c"])
        XCTAssertEqual(decoded.activeTabId, "b")
    }

    @MainActor
    func test_openTabAppendsAndActivates() {
        let store = LiveEditorStore()
        let initialCount = store.state.openTabs.count
        store.openTab("sequence-1-basic")
        XCTAssertEqual(store.state.openTabs.count, initialCount + 1)
        XCTAssertEqual(store.state.activeTabId, "sequence-1-basic")
    }

    @MainActor
    func test_openTabIsIdempotent() {
        let store = LiveEditorStore()
        store.openTab("dup")
        store.openTab("dup")
        XCTAssertEqual(store.state.openTabs.filter { $0 == "dup" }.count, 1)
        XCTAssertEqual(store.state.activeTabId, "dup")
    }

    @MainActor
    func test_closeTabKeepsActiveAlive() {
        let store = LiveEditorStore()
        store.openTab("a")
        store.openTab("b")
        store.activateTab("a")
        store.closeTab("b")
        XCTAssertFalse(store.state.openTabs.contains("b"))
        XCTAssertEqual(store.state.activeTabId, "a")
    }

    @MainActor
    func test_closeActiveTabFallsBackToFirstRemaining() {
        let store = LiveEditorStore()
        store.openTab("a")
        store.openTab("b")
        store.activateTab("b")
        store.closeTab("b")
        XCTAssertFalse(store.state.openTabs.contains("b"))
        XCTAssertEqual(store.state.activeTabId, store.state.openTabs.first)
    }
}
