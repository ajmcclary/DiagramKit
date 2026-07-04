//
//  ShapeCatalogTests.swift
//  DiagramKitTests
//
//  Visual editor plan 2 — catalog data integrity: every alias must
//  resolve, no duplicates, all categories populated, search works.
//

import XCTest
import DiagramKitModel
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
final class ShapeCatalogTests: XCTestCase {

    func test_everyAliasResolvesToANodeShape() {
        for item in ShapeCatalog.all {
            XCTAssertNotNil(
                original_src_types.NodeShape.resolve(alias: item.alias),
                "catalog alias '\(item.alias)' does not resolve"
            )
        }
    }

    func test_noDuplicateAliases() {
        let aliases = ShapeCatalog.all.map(\.alias)
        XCTAssertEqual(aliases.count, Set(aliases).count)
    }

    func test_allCategoriesNonEmpty() {
        for category in ShapeCatalogCategory.allCases {
            XCTAssertFalse(category.items.isEmpty, "\(category.rawValue) is empty")
        }
    }

    func test_allEqualsConcatenationOfCategories() {
        let concatenated = ShapeCatalogCategory.allCases.flatMap(\.items)
        XCTAssertEqual(ShapeCatalog.all, concatenated)
    }

    func test_searchMatchesNameCaseInsensitively() {
        let hits = ShapeCatalog.search("DATA")
        XCTAssertTrue(hits.contains { $0.alias == "bow-tie-rectangle" })
    }

    func test_searchMatchesAlias() {
        let hits = ShapeCatalog.search("cyl")
        XCTAssertTrue(hits.contains { $0.alias == "cylinder" })
    }

    func test_emptySearchReturnsAll() {
        XCTAssertEqual(ShapeCatalog.search(""), ShapeCatalog.all)
        XCTAssertEqual(ShapeCatalog.search("   "), ShapeCatalog.all)
    }
}
