//
//  CorpusBrowserTests.swift
//  DiagramPlaygroundUITests
//
//  Phase 8 / Task 8.5 — corpus browser shows the grid, search field,
//  and at least one corpus thumbnail card.
//

import XCTest

final class CorpusBrowserTests: XCTestCase {

    @MainActor
    func test_browserShowsGridAndSearch() {
        let app = launchPlayground(initialState: .corpus)
        for id in ["corpus.browser.grid", "corpus.browser.search"] {
            let element = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: 10), "'\(id)' missing")
        }
    }

    @MainActor
    func test_atLeastOneThumbnailIsAddressable() {
        let app = launchPlayground(initialState: .corpus)
        // Thumbnails carry identifiers of the form "corpus.thumbnail.<id>".
        // Match any one; the exact id can shift with corpus reordering.
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'corpus.thumbnail.'")
        let thumbs = app.descendants(matching: .any).matching(predicate)
        // Allow some time for the LazyVGrid to materialize the first row.
        let first = thumbs.firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "No corpus thumbnail rendered")
    }
}
