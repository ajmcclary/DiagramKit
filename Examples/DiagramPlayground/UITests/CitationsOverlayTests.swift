//
//  CitationsOverlayTests.swift
//  DiagramPlaygroundUITests
//
//  Phase 10 / Task 10.5 — toggling the inspector's citation toggle
//  reveals numbered pins on the active screen.
//

import XCTest

final class CitationsOverlayTests: XCTestCase {

    @MainActor
    func test_citationsOverlayRendersWhenToggleOn() {
        let app = launchPlayground(initialState: .citationsOn)
        let overlay = app.descendants(matching: .any).matching(identifier: "citation.overlay").firstMatch
        XCTAssertTrue(overlay.waitForExistence(timeout: 10), "Citation overlay missing when toggle on")
    }

    @MainActor
    func test_atLeastOnePinIsAddressable() {
        let app = launchPlayground(initialState: .citationsOn)
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'citation.pin.'")
        let pins = app.descendants(matching: .any).matching(predicate)
        XCTAssertTrue(pins.firstMatch.waitForExistence(timeout: 10), "No citation pins rendered")
    }
}
