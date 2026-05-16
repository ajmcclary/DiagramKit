//
//  ExportSheetTests.swift
//  DiagramPlaygroundUITests
//
//  Phase 7 / Task 7.1 — export sheet shows the 10 targets, round-trip
//  toggle, Copy and Save controls.
//

import XCTest

final class ExportSheetTests: XCTestCase {

    @MainActor
    func test_sheetSurfacesAllTenTargets() {
        let app = launchPlayground(initialState: .exportSheetOpen)
        let sheet = app.descendants(matching: .any).matching(identifier: "sheet.export").firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "Export sheet missing")

        for target in ["svg", "png1x", "png2x", "png3x", "ascii",
                       "mermaid", "d2", "dot", "structurizr", "plantuml"] {
            let id = "sheet.export.target.\(target)"
            let row = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 3), "Export target '\(target)' missing")
        }
    }

    @MainActor
    func test_copyAndSaveControlsExist() {
        let app = launchPlayground(initialState: .exportSheetOpen)
        for id in ["sheet.export.copy", "sheet.export.save", "sheet.export.rtToggle"] {
            let control = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(control.waitForExistence(timeout: 10), "Control '\(id)' missing")
        }
    }

    @MainActor
    func test_copyButtonIsHittable() {
        let app = launchPlayground(initialState: .exportSheetOpen)
        let copy = app.descendants(matching: .any).matching(identifier: "sheet.export.copy").firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 10))
        XCTAssertTrue(copy.isHittable)
        copy.tap()
        // Pasteboard verification is out of scope here; the tap proves
        // the button dispatches without throwing.
    }
}
