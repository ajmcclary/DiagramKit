//
//  DiagnosticsFilterTests.swift
//  DiagramKitTests
//
//  Phase 6 / Task 6.1 — DiagnosticsDrawerState defaults, codec
//  round-trip, and the filtered-view predicate on the store.
//

import XCTest
@testable import DiagramPlayground
import DiagramKitCommon

@available(iOS 26.0, macOS 26.0, *)
final class DiagnosticsFilterTests: XCTestCase {

    // MARK: - Defaults

    func test_drawerStateDefaults() {
        let s = DiagnosticsDrawerState()
        XCTAssertFalse(s.isOpen)
        XCTAssertEqual(s.severity, .all)
        XCTAssertNil(s.category)
        XCTAssertEqual(s.tier, .all)
        XCTAssertEqual(s.paired, .all)
    }

    func test_diagDrawerOnEditorStateDefaults() {
        let state = LiveEditorState()
        XCTAssertFalse(state.diagDrawer.isOpen)
        XCTAssertEqual(state.diagDrawer.severity, .all)
        XCTAssertNil(state.diagDrawer.category)
    }

    // MARK: - Codec round-trip

    func test_drawerSurvivesCodecRoundTripWithCategoryAndSeverity() throws {
        var s = LiveEditorState()
        s.diagDrawer.isOpen = true
        s.diagDrawer.severity = .warning
        s.diagDrawer.category = .subgraphFlatten
        s.diagDrawer.tier = .import
        s.diagDrawer.paired = .paired
        let encoded = LiveEditorStateCodec.encode(s)
        let decoded = try LiveEditorStateCodec.decode(encoded)
        XCTAssertTrue(decoded.diagDrawer.isOpen)
        XCTAssertEqual(decoded.diagDrawer.severity, .warning)
        XCTAssertEqual(decoded.diagDrawer.category, .subgraphFlatten)
        XCTAssertEqual(decoded.diagDrawer.tier, .import)
        XCTAssertEqual(decoded.diagDrawer.paired, .paired)
    }

    // MARK: - Store toggle

    @MainActor
    func test_toggleDiagnosticsDrawerFlipsOpen() {
        let store = LiveEditorStore()
        XCTAssertFalse(store.state.diagDrawer.isOpen)
        store.toggleDiagnosticsDrawer()
        XCTAssertTrue(store.state.diagDrawer.isOpen)
        store.toggleDiagnosticsDrawer()
        XCTAssertFalse(store.state.diagDrawer.isOpen)
    }
}
