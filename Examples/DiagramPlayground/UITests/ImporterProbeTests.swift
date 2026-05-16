//
//  ImporterProbeTests.swift
//  DiagramPlaygroundUITests
//
//  Phase 9 / Task 9.2 — importer probe full-screen surface shows
//  the sample picker and at least one probe step.
//

import XCTest

final class ImporterProbeTests: XCTestCase {

    @MainActor
    func test_probeScreenRenders() {
        let app = launchPlayground(initialState: .probe)
        let view = app.descendants(matching: .any).matching(identifier: "probe.view").firstMatch
        XCTAssertTrue(view.waitForExistence(timeout: 10), "Probe view missing")
    }

    @MainActor
    func test_sampleListIsAddressable() {
        let app = launchPlayground(initialState: .probe)
        // Sample buttons carry "probe.sample.<index>" ids; pin the first.
        let first = app.descendants(matching: .any).matching(identifier: "probe.sample.0").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "First probe sample row missing")
    }

    @MainActor
    func test_atLeastOneStepIsAddressable() {
        let app = launchPlayground(initialState: .probe)
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'probe.step.'")
        let steps = app.descendants(matching: .any).matching(predicate)
        let first = steps.firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "No probe step rendered")
    }
}
