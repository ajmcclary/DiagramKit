//
//  SmokeTests.swift
//  DiagramPlaygroundUITests
//
//  Proves the UI-test harness boots before any audit work lands.
//

import XCTest

final class SmokeTests: XCTestCase {
    @MainActor
    func testAppLaunchesEmptyState() {
        let app = launchPlayground(initialState: .empty)
        XCTAssertTrue(app.windows.firstMatch.exists, "Main window should exist")
    }
}
