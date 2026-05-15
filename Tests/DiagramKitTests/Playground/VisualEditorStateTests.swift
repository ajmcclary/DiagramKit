//
//  VisualEditorStateTests.swift
//  DiagramKitTests
//
//  Phase 3 / Task 3.1 — VisualEditorState enums, the new state
//  fields on LiveEditorState, and the store's visualEditor alias.
//

import XCTest
@testable import DiagramPlayground

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class VisualEditorStateTests: XCTestCase {

    // MARK: - Enums

    func test_stageHasSevenCases() {
        XCTAssertEqual(VisualEditorState.Stage.allCases.count, 7)
    }

    func test_toolHasFourCases() {
        XCTAssertEqual(VisualEditorState.Tool.allCases.count, 4)
    }

    // MARK: - Defaults

    func test_visualStateDefaults() {
        let s = LiveEditorState()
        XCTAssertEqual(s.visualStage, .idle)
        XCTAssertEqual(s.visualTool, .select)
        XCTAssertTrue(s.marqueeSelection.isEmpty)
        XCTAssertFalse(s.demoStepperVisible)
    }

    // MARK: - Codec round-trip

    func test_visualStateSurvivesCodecRoundTrip() throws {
        var s = LiveEditorState()
        s.visualStage = .nodeSelected
        s.visualTool = .connector
        s.marqueeSelection = ["A", "B"]
        s.demoStepperVisible = true
        let encoded = LiveEditorStateCodec.encode(s)
        let decoded = try LiveEditorStateCodec.decode(encoded)
        XCTAssertEqual(decoded.visualStage, .nodeSelected)
        XCTAssertEqual(decoded.visualTool, .connector)
        XCTAssertEqual(decoded.marqueeSelection, ["A", "B"])
        XCTAssertTrue(decoded.demoStepperVisible)
    }

    func test_legacySnapshotDecodesWithDefaults() throws {
        let legacyJSON = """
        {"source":"flowchart TD\\nA --> B\\n","selectedThemeName":"Zinc Light","configJSON":"{}","gridEnabled":false,"panZoomEnabled":true,"editorMode":"code","updateMode":"auto","sourceFormat":"mermaid"}
        """
        let data = Data(legacyJSON.utf8)
        let decoded = try JSONDecoder().decode(LiveEditorState.self, from: data)
        XCTAssertEqual(decoded.visualStage, .idle)
        XCTAssertEqual(decoded.visualTool, .select)
        XCTAssertTrue(decoded.marqueeSelection.isEmpty)
        XCTAssertFalse(decoded.demoStepperVisible)
    }

    // MARK: - Store

    @MainActor
    func test_visualEditorMirrorsEditor() {
        let store = LiveEditorStore()
        XCTAssertTrue(store.visualEditor === store.editor)
    }

    @MainActor
    func test_setVisualStageWritesThrough() {
        let store = LiveEditorStore()
        store.setVisualStage(.labelEdited)
        XCTAssertEqual(store.state.visualStage, .labelEdited)
    }

    @MainActor
    func test_setVisualToolWritesThrough() {
        let store = LiveEditorStore()
        store.setVisualTool(.marquee)
        XCTAssertEqual(store.state.visualTool, .marquee)
    }

    @MainActor
    func test_setMarqueeSelectionWritesThrough() {
        let store = LiveEditorStore()
        store.setMarqueeSelection(["A", "B", "C"])
        XCTAssertEqual(store.state.marqueeSelection, ["A", "B", "C"])
        store.setMarqueeSelection([])
        XCTAssertTrue(store.state.marqueeSelection.isEmpty)
    }
}
