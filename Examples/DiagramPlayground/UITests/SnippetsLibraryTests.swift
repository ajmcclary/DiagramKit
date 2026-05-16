//
//  SnippetsLibraryTests.swift
//  DiagramPlaygroundUITests
//
//  Phase 9 / Task 9.3 — snippets library shows the search field and
//  at least one snippet card.
//

import XCTest

final class SnippetsLibraryTests: XCTestCase {

    @MainActor
    func test_snippetsScreenRenders() {
        let app = launchPlayground(initialState: .snippets)
        for id in ["snippets.view", "snippets.search"] {
            let element = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: 10), "'\(id)' missing")
        }
    }

    @MainActor
    func test_atLeastOneCardIsAddressable() {
        let app = launchPlayground(initialState: .snippets)
        let predicate = NSPredicate(format: "identifier BEGINSWITH 'snippets.card.'")
        let cards = app.descendants(matching: .any).matching(predicate)
        let first = cards.firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "No snippet card rendered")
    }
}
