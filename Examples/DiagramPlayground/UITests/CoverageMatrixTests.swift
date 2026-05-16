//
//  CoverageMatrixTests.swift
//  DiagramPlaygroundUITests
//
//  Phase 8 / Task 8.3 — coverage full-screen surface renders the
//  28×5 grid.
//

import XCTest

final class CoverageMatrixTests: XCTestCase {

    @MainActor
    func test_coverageScreenRendersGrid() {
        let app = launchPlayground(initialState: .coverage)
        let grid = app.descendants(matching: .any).matching(identifier: "coverage.matrix.grid").firstMatch
        XCTAssertTrue(grid.waitForExistence(timeout: 10), "Coverage matrix grid missing")
    }

    @MainActor
    func test_atLeastOneCellIsAddressable() {
        let app = launchPlayground(initialState: .coverage)
        // Cell identifier shape: coverage.cell.<family>.<format>
        let flowchartMermaid = app.descendants(matching: .any)
            .matching(identifier: "coverage.cell.flowchart.mermaid").firstMatch
        XCTAssertTrue(
            flowchartMermaid.waitForExistence(timeout: 10),
            "Flowchart/Mermaid host cell not addressable"
        )
    }
}
