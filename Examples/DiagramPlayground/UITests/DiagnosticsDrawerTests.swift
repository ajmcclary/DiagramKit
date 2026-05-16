//
//  DiagnosticsDrawerTests.swift
//  DiagramPlaygroundUITests
//
//  Phase 6 — diagnostics drawer opens, severity / tier / paired
//  chips render, category list renders.
//

import XCTest

final class DiagnosticsDrawerTests: XCTestCase {

    @MainActor
    func test_drawerOpensWithFacetChips() {
        let app = launchPlayground(initialState: .diagDrawerOpen)
        let drawer = app.descendants(matching: .any).matching(identifier: "diagnostics.drawer").firstMatch
        XCTAssertTrue(drawer.waitForExistence(timeout: 10), "Diagnostics drawer missing")

        for chip in ["diagnostics.severity.all", "diagnostics.tier.all", "diagnostics.paired.all"] {
            let element = app.descendants(matching: .any).matching(identifier: chip).firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: 3), "Facet chip '\(chip)' missing")
        }
    }

    @MainActor
    func test_severityFilterIsHittable() {
        let app = launchPlayground(initialState: .diagDrawerOpen)
        let warningChip = app.descendants(matching: .any).matching(identifier: "diagnostics.severity.warning").firstMatch
        XCTAssertTrue(warningChip.waitForExistence(timeout: 10))
        warningChip.tap()
        // No row-count assertion — depends on the seeded source. The
        // tap itself is the contract: a renamed identifier would fail
        // the existence check above.
    }

    @MainActor
    func test_categoryListRenders() {
        let app = launchPlayground(initialState: .diagDrawerOpen)
        let list = app.descendants(matching: .any).matching(identifier: "diagnostics.categoryList").firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10), "Category list missing")
    }
}
