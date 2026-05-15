//
//  SnippetLibraryTests.swift
//  DiagramKitTests
//
//  Phase 9 / Task 9.3 — pins the 28-pattern library shape +
//  search predicate. Per-snippet parse-roundtrips are out of scope
//  here; some families need fixtures (renderEnd dates, etc.) that
//  belong in the library snapshot suite, not playground glue.
//

import XCTest
@testable import DiagramPlayground
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class SnippetLibraryTests: XCTestCase {

    func test_libraryHas28Snippets() {
        XCTAssertEqual(SnippetLibrary.all.count, 28)
    }

    func test_oneSnippetPerFamily() {
        let families = Set(SnippetLibrary.all.map(\.family))
        XCTAssertEqual(families.count, 28)
        XCTAssertEqual(families, Set(DiagramType.allCases))
    }

    func test_everySnippetHasNonEmptyBodyAndUniqueId() {
        var ids = Set<String>()
        for snippet in SnippetLibrary.all {
            XCTAssertFalse(snippet.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           "\(snippet.id)")
            XCTAssertFalse(ids.contains(snippet.id), "duplicate id \(snippet.id)")
            ids.insert(snippet.id)
        }
    }

    func test_searchByTitleSubstring() {
        let hits = SnippetLibrary.filtered("flow")
        XCTAssertTrue(hits.contains(where: { $0.id == "flowchart" }))
    }

    func test_searchEmptyReturnsAll() {
        XCTAssertEqual(SnippetLibrary.filtered("").count, SnippetLibrary.all.count)
    }
}
