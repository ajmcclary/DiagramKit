//
//  ExportSheetStateTests.swift
//  DiagramKitTests
//
//  Phase 7 / Task 7.1 — ExportSheetState defaults, codec round-trip,
//  and store helpers.
//

import XCTest
@testable import DiagramPlayground

@available(iOS 26.0, macOS 26.0, *)
final class ExportSheetStateTests: XCTestCase {

    func test_exportSheetDefaults() {
        let s = LiveEditorState()
        XCTAssertFalse(s.exportSheet.isOpen)
        XCTAssertEqual(s.exportSheet.target, .svg)
        XCTAssertFalse(s.exportSheet.rtCheck)
        XCTAssertFalse(s.convertSheet.isOpen)
        XCTAssertEqual(s.convertSheet.target, .d2)
    }

    func test_targetGroupingMatchesDesign() {
        let renderTargets = ExportTarget.allCases.filter { $0.groupLabel == "Render" }
        let sourceTargets = ExportTarget.allCases.filter { $0.groupLabel == "Source" }
        XCTAssertEqual(renderTargets.count, 5) // svg + 3 png + ascii
        XCTAssertEqual(sourceTargets.count, 5) // mermaid + d2 + dot + structurizr + plantuml
    }

    func test_codecRoundTripsExportAndConvertState() throws {
        var s = LiveEditorState()
        s.exportSheet.isOpen = true
        s.exportSheet.target = .png2x
        s.exportSheet.rtCheck = true
        s.convertSheet.isOpen = true
        s.convertSheet.target = .plantuml
        let encoded = LiveEditorStateCodec.encode(s)
        let decoded = try LiveEditorStateCodec.decode(encoded)
        XCTAssertTrue(decoded.exportSheet.isOpen)
        XCTAssertEqual(decoded.exportSheet.target, .png2x)
        XCTAssertTrue(decoded.exportSheet.rtCheck)
        XCTAssertTrue(decoded.convertSheet.isOpen)
        XCTAssertEqual(decoded.convertSheet.target, .plantuml)
    }

    @MainActor
    func test_openExportSheetSetsTargetAndIsOpen() {
        let store = LiveEditorStore()
        store.openExportSheet(at: .ascii)
        XCTAssertTrue(store.state.exportSheet.isOpen)
        XCTAssertEqual(store.state.exportSheet.target, .ascii)
        store.closeExportSheet()
        XCTAssertFalse(store.state.exportSheet.isOpen)
    }
}
