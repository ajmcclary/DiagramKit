//
//  MinimapStateTests.swift
//  DiagramKitTests
//
//  Phase 2 / Task 2.2 — showMinimap defaults to true and survives the
//  codec round-trip. The Canvas-based view itself is exercised via
//  the UITests in WorkspaceShellSmokeTests (added in a later phase).
//

import XCTest
@testable import DiagramPlayground

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class MinimapStateTests: XCTestCase {

    func test_showMinimapDefaultsToTrue() {
        XCTAssertTrue(LiveEditorState().showMinimap)
    }

    func test_showMinimapSurvivesCodecRoundTrip() throws {
        var state = LiveEditorState()
        state.showMinimap = false
        let encoded = LiveEditorStateCodec.encode(state)
        let decoded = try LiveEditorStateCodec.decode(encoded)
        XCTAssertFalse(decoded.showMinimap)
    }

    func test_legacySnapshotDecodesAsTrue() throws {
        let legacyJSON = """
        {"source":"flowchart TD\\nA --> B\\n","selectedThemeName":"Zinc Light","configJSON":"{}","gridEnabled":false,"panZoomEnabled":true,"editorMode":"code","updateMode":"auto","sourceFormat":"mermaid"}
        """
        let data = Data(legacyJSON.utf8)
        let decoded = try JSONDecoder().decode(LiveEditorState.self, from: data)
        XCTAssertTrue(decoded.showMinimap)
    }
}
