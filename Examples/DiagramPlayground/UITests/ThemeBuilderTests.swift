//
//  ThemeBuilderTests.swift
//  DiagramPlaygroundUITests
//
//  Phase 10 / Task 10.1 — the inspector's ThemeBuilder card exposes
//  every token row plus a reset-all action.
//

import XCTest

final class ThemeBuilderTests: XCTestCase {

    @MainActor
    func test_cardRendersAllTwelveTokenRows() {
        let app = launchPlayground(initialState: .editingFlow1Inspector)
        let card = app.descendants(matching: .any).matching(identifier: "inspector.themeBuilder").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "ThemeBuilder card missing")

        let tokens = ["bg", "fg", "surface", "border", "line", "accent",
                      "muted", "noteBkg", "noteBorder",
                      "success", "warning", "error"]
        for token in tokens {
            let id = "themebuilder.token.\(token)"
            let row = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 3), "ThemeBuilder row '\(token)' missing")
        }
    }

    @MainActor
    func test_resetAllControlIsAddressable() {
        let app = launchPlayground(initialState: .editingFlow1Inspector)
        let reset = app.descendants(matching: .any).matching(identifier: "themebuilder.resetAll").firstMatch
        XCTAssertTrue(reset.waitForExistence(timeout: 10), "ThemeBuilder reset-all control missing")
    }
}
