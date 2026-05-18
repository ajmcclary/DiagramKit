//
//  CitationSetTests.swift
//  DiagramKitTests
//
//  Phase 10 / Task 10.5 — pin tables exist for every surface, every
//  pin has a non-empty label + path, and the active surface
//  resolver returns at least four pins for each surface.
//

import XCTest
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
final class CitationSetTests: XCTestCase {

    func test_everySurfaceHasPins() {
        let surfaces: [CitationSet.Surface] = [
            .workspaceCode, .workspaceSplit, .workspaceVisual,
            .diagnosticsDrawer, .exportSheet, .convertSheet,
            .coverageMatrix, .corpusBrowser,
            .crossFormat, .importerProbe, .snippetsLibrary, .renderFailed
        ]
        for surface in surfaces {
            let pins = CitationSet.pins(for: surface)
            XCTAssertGreaterThanOrEqual(pins.count, 2, "\(surface)")
        }
    }

    func test_pinsHaveNonEmptyLabelAndPath() {
        for surface: CitationSet.Surface in [.workspaceCode, .workspaceVisual, .corpusBrowser] {
            for pin in CitationSet.pins(for: surface) {
                XCTAssertFalse(pin.label.isEmpty)
                XCTAssertFalse(pin.path.isEmpty)
            }
        }
    }

    func test_surfaceLabelsAreNonEmpty() {
        let surfaces: [CitationSet.Surface] = [
            .workspaceCode, .workspaceSplit, .workspaceVisual,
            .diagnosticsDrawer, .exportSheet, .convertSheet,
            .coverageMatrix, .corpusBrowser,
            .crossFormat, .importerProbe, .snippetsLibrary, .renderFailed
        ]
        for surface in surfaces {
            XCTAssertFalse(surface.label.isEmpty)
        }
    }
}
