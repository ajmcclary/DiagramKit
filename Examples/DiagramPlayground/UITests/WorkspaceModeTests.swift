//
//  WorkspaceModeTests.swift
//  DiagramPlaygroundUITests
//
//  Phase 1 / Task 1.3 — the Titlebar's three-way mode picker is
//  reachable, every chip is hittable, and Split mode is selectable.
//

import XCTest

final class WorkspaceModeTests: XCTestCase {

    @MainActor
    func test_titlebarHasAllThreeModeButtons() {
        let app = launchPlayground(initialState: .editingFlow1)
        for id in ["titlebar.mode.code", "titlebar.mode.visual", "titlebar.mode.split"] {
            let chip = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(
                chip.waitForExistence(timeout: 10),
                "Mode chip '\(id)' missing from titlebar"
            )
        }
    }

    @MainActor
    func test_splitModeIsHittable() {
        let app = launchPlayground(initialState: .editingFlow1)
        let split = app.descendants(matching: .any).matching(identifier: "titlebar.mode.split").firstMatch
        XCTAssertTrue(split.waitForExistence(timeout: 10))
        split.tap()
        // No assertion on body layout — split-mode rendering is covered
        // by snapshot work; this just proves the chip dispatches without
        // throwing.
    }

    @MainActor
    func test_visualModeIsEnabledAfterPhase3() {
        let app = launchPlayground(initialState: .editingFlow1)
        let visual = app.descendants(matching: .any).matching(identifier: "titlebar.mode.visual").firstMatch
        XCTAssertTrue(visual.waitForExistence(timeout: 10))
        XCTAssertTrue(visual.isHittable, "Visual mode should be enabled — Phase 3 wired the canvas")
    }
}
