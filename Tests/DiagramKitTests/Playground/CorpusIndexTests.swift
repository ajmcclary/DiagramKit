//
//  CorpusIndexTests.swift
//  DiagramKitTests
//
//  Phase 8 / Task 8.4 — exercises CorpusIndex.shared on the real
//  test-diagrams.json corpus and the predicate-based filter.
//

import XCTest
@testable import DiagramPlayground

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class CorpusIndexTests: XCTestCase {

    func test_sharedHasEntriesAndCounts() {
        let index = CorpusIndex.shared
        XCTAssertGreaterThan(index.entries.count, 100, "corpus shouldn't be empty")
        XCTAssertGreaterThan(index.categoryCounts.keys.count, 0)
    }

    func test_everyEntryHasNonEmptySource() {
        for entry in CorpusIndex.shared.entries {
            XCTAssertFalse(entry.source.isEmpty, "\(entry.id)")
        }
    }

    func test_approximateLinuxFacetCoversCoreTextBoundFamilies() {
        let names = Set(
            CorpusIndex.shared.entries
                .filter { $0.linuxFacet == .approximate }
                .map(\.category)
                .map { $0.lowercased() }
        )
        XCTAssertTrue(names.contains("ishikawa") || names.contains("treeview") || names.contains("eventmodeling"))
    }

    func test_filterByCategoryWorks() {
        let count = CorpusIndex.shared.filtered(
            search: "",
            category: "flowchart",
            format: nil,
            diagnostic: nil,
            linux: nil
        ).count
        XCTAssertGreaterThan(count, 10)
    }

    func test_filterBySearchMatchesIdSubstring() {
        let entries = CorpusIndex.shared.filtered(
            search: "flow-1",
            category: nil,
            format: nil,
            diagnostic: nil,
            linux: nil
        )
        XCTAssertTrue(entries.contains(where: { $0.id == "flow-1-simple" }))
    }
}
