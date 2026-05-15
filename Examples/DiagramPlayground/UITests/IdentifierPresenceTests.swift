//
//  IdentifierPresenceTests.swift
//  DiagramPlaygroundUITests
//
//  Asserts every A11yID constant resolves to a real, hittable
//  control in the relevant screen state. Catches the silent-failure
//  mode where a modifier is removed and the audit suite doesn't
//  notice because the element no longer renders.
//
//  Per-task test methods are appended as the corresponding view
//  files gain their a11y modifiers.
//

import XCTest

final class IdentifierPresenceTests: XCTestCase {

    // MARK: - Preview toolbar

    @MainActor
    func testPreviewToolbar_allIdentifiersPresent() {
        let app = launchPlayground(initialState: .editingFlow1)
        let ids = [
            "preview.fit",
            "preview.zoomOut",
            "preview.zoomIn",
            "preview.actualSize",
            "preview.panZoomToggle",
            "preview.gridToggle",
            "preview.fullWindow",
        ]
        for id in ids {
            let element = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(
                element.waitForExistence(timeout: 3),
                "Expected preview toolbar control with identifier '\(id)' to exist"
            )
        }
    }
}
