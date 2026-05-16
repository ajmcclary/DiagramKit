//
//  AccessibilityAuditTests.swift
//  DiagramPlaygroundUITests
//
//  Drives XCUIApplication.performAccessibilityAudit across each
//  major screen state. Audit issue types include missing labels,
//  duplicate labels, hit-target size, contrast, dynamic-type
//  clipping, and trait coherence.
//

import XCTest

@available(macOS 14.0, *)
final class AccessibilityAuditTests: XCTestCase {

    @MainActor
    func testEmptyState() throws {
        let app = launchPlayground(initialState: .empty)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testEditingState() throws {
        let app = launchPlayground(initialState: .editingFlow1)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testSelectionState() throws {
        let app = launchPlayground(initialState: .selectionFlow1)
        // Select a node via the selection picker to exercise selection
        // / rename / delete controls.
        let picker = app.descendants(matching: .any).matching(identifier: "editor.selection.picker").firstMatch
        if picker.waitForExistence(timeout: 3) {
            picker.click()
            // First non-"None" item in the menu. SwiftUI menu rendering
            // varies; tolerate the absence by skipping selection if the
            // menu items don't surface as tappable.
            let firstNode = app.menuItems.element(boundBy: 1)
            if firstNode.waitForExistence(timeout: 2) {
                firstNode.click()
            }
        }
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testErrorState() throws {
        let app = launchPlayground(initialState: .errorGarbage)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testThemePickerOpenState() throws {
        let app = launchPlayground(initialState: .themeOpen)
        let theme = app.descendants(matching: .any).matching(identifier: "toolbar.theme").firstMatch
        XCTAssertTrue(theme.waitForExistence(timeout: 3))
        theme.click()
        try app.performAccessibilityAudit()
    }

    // MARK: - v2 PlaygroundShell screens (Phase 10 / Task 10.6)

    @MainActor
    func testVisualFlowState() throws {
        let app = launchPlayground(initialState: .visualFlow)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testVisualSequenceState() throws {
        let app = launchPlayground(initialState: .visualSequence)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testVisualGanttState() throws {
        let app = launchPlayground(initialState: .visualGantt)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testDiagnosticsDrawerState() throws {
        let app = launchPlayground(initialState: .diagDrawerOpen)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testExportSheetState() throws {
        let app = launchPlayground(initialState: .exportSheetOpen)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testConvertSheetState() throws {
        let app = launchPlayground(initialState: .convertSheetOpen)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testCoverageMatrixState() throws {
        let app = launchPlayground(initialState: .coverage)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testCorpusBrowserState() throws {
        let app = launchPlayground(initialState: .corpus)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testCrossFormatState() throws {
        let app = launchPlayground(initialState: .crossFormat)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testProbeState() throws {
        let app = launchPlayground(initialState: .probe)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testSnippetsState() throws {
        let app = launchPlayground(initialState: .snippets)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testCitationsOnState() throws {
        let app = launchPlayground(initialState: .citationsOn)
        try app.performAccessibilityAudit()
    }
}
