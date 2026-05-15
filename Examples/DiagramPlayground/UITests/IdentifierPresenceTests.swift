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

    // MARK: - DiagramEditorPane

    @MainActor
    func testEditorPane_allIdentifiersPresent() {
        let app = launchPlayground(initialState: .editingFlow1)
        let ids = [
            "editor.title.set",
            "editor.title.clear",
            "editor.title.close",
            "editor.selection.picker",
            "editor.label.rename",
            "editor.insertNode.button",
            "editor.insertNode.shape",
            "editor.insertEdge.button",
            "editor.insertEdge.from",
            "editor.insertEdge.to",
            "editor.delete.selected",
            "editor.undo",
            "editor.redo",
        ]
        for id in ids {
            let candidate = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(
                candidate.waitForExistence(timeout: 3),
                "Expected editor-pane control with identifier '\(id)' to exist"
            )
        }
    }

    // MARK: - PreviewCanvas

    @MainActor
    func testPreviewCanvas_modePickerPresent() {
        let app = launchPlayground(initialState: .editingFlow1)
        let picker = app.descendants(matching: .any).matching(identifier: "preview.mode").firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 3), "Preview mode picker missing")
    }

    // MARK: - Sample panel

    @MainActor
    func testSamplePanel_searchControlsPresent() {
        let app = launchPlayground(initialState: .editingFlow1)
        let search = app.descendants(matching: .any).matching(identifier: "picker.sampleSearch").firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3), "Sample search field missing")
        // Type a query to surface the clear button.
        search.click()
        search.typeText("flow")
        let clear = app.descendants(matching: .any).matching(identifier: "picker.sampleSearchClear").firstMatch
        XCTAssertTrue(clear.waitForExistence(timeout: 3), "Sample search clear button missing")
    }

    // MARK: - LiveEditorToolbar

    // MARK: - Small pickers

    @MainActor
    func testSmallPickers_allIdentifiersPresent() {
        let app = launchPlayground(initialState: .editingFlow1)
        let ids = [
            "picker.editorMode",
            "picker.sourceFormat",
            "picker.themeMenu",
        ]
        for id in ids {
            let candidate = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(
                candidate.waitForExistence(timeout: 3),
                "Expected picker with identifier '\(id)' to exist"
            )
        }
    }

    @MainActor
    func testToolbar_macOS_allIdentifiersPresent() {
        let app = launchPlayground(initialState: .editingFlow1)
        let ids = [
            "toolbar.theme",
            "toolbar.view",
            "toolbar.actions",
            "toolbar.info",
            "toolbar.inspector",
            "toolbar.updateMode",
        ]
        for id in ids {
            let candidate = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(
                candidate.waitForExistence(timeout: 3),
                "Expected toolbar control with identifier '\(id)' to exist"
            )
        }
    }
}
