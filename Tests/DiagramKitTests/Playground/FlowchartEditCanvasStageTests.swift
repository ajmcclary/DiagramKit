//
//  FlowchartEditCanvasStageTests.swift
//  DiagramKitTests
//
//  Phase 3 / Task 3.3 — pins the data-layer half of the seven-stage
//  state machine. Pure-SwiftUI gesture wiring inside FlowchartEditCanvas
//  is exercised via UITests in a later phase.
//

import XCTest
@testable import DiagramPlayground

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class FlowchartEditCanvasStageTests: XCTestCase {

    @MainActor
    func test_setVisualStageWalksAllSevenStages() {
        let store = LiveEditorStore()
        for stage in VisualEditorState.Stage.allCases {
            store.setVisualStage(stage)
            XCTAssertEqual(store.state.visualStage, stage)
        }
    }

    @MainActor
    func test_marqueeAndSelectionAreIndependent() {
        let store = LiveEditorStore()
        store.setMarqueeSelection(["A", "B"])
        XCTAssertEqual(store.state.marqueeSelection, ["A", "B"])
        XCTAssertNil(store.editor?.selection)
    }
}
