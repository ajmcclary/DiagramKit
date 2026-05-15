//
//  WorkspaceModePersistenceTests.swift
//  DiagramKitTests
//
//  Phase 1 / Task 1.2 — workspaceMode + showCitations persist through
//  LiveEditorStateCodec, and the store exposes setters for each.
//

import XCTest
@testable import DiagramPlayground

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class WorkspaceModePersistenceTests: XCTestCase {

    func test_workspaceModeDefaultsMatchType() {
        let state = LiveEditorState()
        XCTAssertEqual(state.workspaceMode, .default)
        XCTAssertFalse(state.showCitations)
    }

    func test_workspaceModeAndCitationsSurviveCodecRoundTrip() throws {
        var state = LiveEditorState()
        state.workspaceMode = .visual
        state.showCitations = true
        state.sidebarSearch = "flow"
        state.sidebarFormatFilter = .d2
        state.renderBackend = .ascii
        let encoded = LiveEditorStateCodec.encode(state)
        let decoded = try LiveEditorStateCodec.decode(encoded)
        XCTAssertEqual(decoded.workspaceMode, .visual)
        XCTAssertTrue(decoded.showCitations)
        XCTAssertEqual(decoded.sidebarSearch, "flow")
        XCTAssertEqual(decoded.sidebarFormatFilter, .d2)
        XCTAssertEqual(decoded.renderBackend, .ascii)
    }

    func test_legacySnapshotDecodesWithDefaults() throws {
        let legacyJSON = """
        {"source":"flowchart TD\\nA --> B\\n","selectedThemeName":"Zinc Light","configJSON":"{}","gridEnabled":false,"panZoomEnabled":true,"editorMode":"code","updateMode":"auto","sourceFormat":"mermaid"}
        """
        let data = Data(legacyJSON.utf8)
        let decoded = try JSONDecoder().decode(LiveEditorState.self, from: data)
        XCTAssertEqual(decoded.workspaceMode, .default)
        XCTAssertFalse(decoded.showCitations)
        XCTAssertEqual(decoded.sidebarSearch, "")
        XCTAssertNil(decoded.sidebarFormatFilter)
        XCTAssertEqual(decoded.renderBackend, .svg)
    }

    @MainActor
    func test_storeSettersMutateState() {
        let store = LiveEditorStore()
        store.setWorkspaceMode(.code)
        XCTAssertEqual(store.state.workspaceMode, .code)
        store.setShowCitations(true)
        XCTAssertTrue(store.state.showCitations)
    }
}
