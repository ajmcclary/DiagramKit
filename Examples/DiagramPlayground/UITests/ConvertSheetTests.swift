//
//  ConvertSheetTests.swift
//  DiagramPlaygroundUITests
//
//  Phase 7 / Task 7.2 — convert sheet shows the four source target
//  chips and a loss list.
//

import XCTest

final class ConvertSheetTests: XCTestCase {

    @MainActor
    func test_sheetSurfacesFourTargetChips() {
        let app = launchPlayground(initialState: .convertSheetOpen)
        let sheet = app.descendants(matching: .any).matching(identifier: "sheet.convert").firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "Convert sheet missing")

        // Mermaid is the source; the picker offers the four other formats.
        for target in ["d2", "dot", "structurizr", "plantuml"] {
            let id = "sheet.convert.target.\(target)"
            let chip = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(chip.waitForExistence(timeout: 3), "Convert target '\(target)' missing")
        }
    }

    @MainActor
    func test_lossListRenders() {
        let app = launchPlayground(initialState: .convertSheetOpen)
        let list = app.descendants(matching: .any).matching(identifier: "sheet.convert.lossList").firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10), "Convert loss list missing")
    }
}
