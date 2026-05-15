//
//  CoverageMatrixSeedTests.swift
//  DiagramKitTests
//
//  Phase 8 / Task 8.2 — pins the 28×5 matrix shape, hostFormat
//  routing, and the registry-derived cell counts.
//

import XCTest
@testable import DiagramPlayground
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class CoverageMatrixSeedTests: XCTestCase {

    func test_matrixShape() {
        let provider = CoverageMatrixProvider()
        XCTAssertEqual(provider.families.count, 28)
        XCTAssertEqual(provider.formats.count, 5)
        XCTAssertEqual(provider.cells.count, 140)
    }

    func test_hostFormatStarsLandOnNativeFormat() {
        let provider = CoverageMatrixProvider()
        for family in provider.families {
            let host = CoverageMatrixSeed.hostFormat(for: family)
            XCTAssertEqual(provider.state(family: family, format: host), .host)
        }
    }

    func test_eachFamilyHasExactlyOneHostCell() {
        let provider = CoverageMatrixProvider()
        for family in provider.families {
            let hostCount = provider.formats
                .map { provider.state(family: family, format: $0) }
                .filter { $0 == .host }
                .count
            XCTAssertEqual(hostCount, 1, "\(family.rawValue)")
        }
    }

    func test_countsCoverEvery140Cells() {
        let provider = CoverageMatrixProvider()
        let total = provider.counts.values.reduce(0, +)
        XCTAssertEqual(total, 140)
    }

    func test_glyphAndDisplayNameForEveryFamily() {
        for family in DiagramType.allCases {
            XCTAssertFalse(CoverageMatrixSeed.glyph(for: family).isEmpty, "glyph: \(family.rawValue)")
            XCTAssertFalse(CoverageMatrixSeed.displayName(for: family).isEmpty, "name: \(family.rawValue)")
        }
    }
}
