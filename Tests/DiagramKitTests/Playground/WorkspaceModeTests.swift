//
//  WorkspaceModeTests.swift
//  DiagramKitTests
//
//  Pins the WorkspaceMode enum shape: ordering, default, and labels.
//  Companion to the v2 PlaygroundShell work in PLAN.md Phase 1.
//

import XCTest
@testable import DiagramPlayground

final class WorkspaceModeTests: XCTestCase {

    func test_allCasesInSourceOrder() {
        XCTAssertEqual(WorkspaceMode.allCases, [.code, .visual, .split])
    }

    func test_defaultIsSplit() {
        XCTAssertEqual(WorkspaceMode.default, .split)
    }

    func test_labelsMatchDesign() {
        XCTAssertEqual(WorkspaceMode.code.label, "Code")
        XCTAssertEqual(WorkspaceMode.visual.label, "Visual")
        XCTAssertEqual(WorkspaceMode.split.label, "Split")
    }

    func test_sfSymbolsAreSet() {
        XCTAssertFalse(WorkspaceMode.code.sfSymbol.isEmpty)
        XCTAssertFalse(WorkspaceMode.visual.sfSymbol.isEmpty)
        XCTAssertFalse(WorkspaceMode.split.sfSymbol.isEmpty)
    }
}
