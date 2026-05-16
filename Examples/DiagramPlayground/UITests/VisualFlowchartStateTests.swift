//
//  VisualFlowchartStateTests.swift
//  DiagramPlaygroundUITests
//
//  Phase 3 — Visual mode renders the flowchart canvas with a tool
//  palette, selection HUD, and undo timeline. Asserts the
//  identifiers that the canvas / palette / HUD register.
//

import XCTest

final class VisualFlowchartStateTests: XCTestCase {

    @MainActor
    func test_visualModeShowsCanvasAndPalette() {
        let app = launchPlayground(initialState: .visualFlow)
        let canvas = app.descendants(matching: .any).matching(identifier: "visual.canvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 10), "Visual canvas missing in flow scenario")

        let palette = app.descendants(matching: .any).matching(identifier: "visual.toolPalette").firstMatch
        XCTAssertTrue(palette.waitForExistence(timeout: 3), "Tool palette missing")

        for tool in ["select", "pan", "marquee", "connector"] {
            let id = "visual.tool.\(tool)"
            let chip = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(chip.waitForExistence(timeout: 3), "Tool chip '\(id)' missing")
        }
    }

    @MainActor
    func test_visualModeShowsSelectionHUDAndUndoTimeline() {
        let app = launchPlayground(initialState: .visualFlow)
        for id in ["visual.selectionHUD", "visual.undoTimeline"] {
            let element = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: 10), "'\(id)' missing in Visual mode")
        }
    }
}
