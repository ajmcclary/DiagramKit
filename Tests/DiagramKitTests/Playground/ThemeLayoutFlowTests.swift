//
//  ThemeLayoutFlowTests.swift
//  DiagramKitTests
//
//  Visual editor plan 6 — toolbar theme/layout flows and the
//  source-pinned theme bridge.
//

#if canImport(CoreGraphics)
import CoreGraphics
import XCTest
import DiagramKit
import DiagramKitInteractive
import DiagramKitModel
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class ThemeLayoutFlowTests: XCTestCase {

    override func setUp() async throws {
        DiagramEngine.bootstrap()
    }

    private func waitForEditor(store: LiveEditorStore, timeout: TimeInterval = 5) async throws {
        let start = Date()
        while store.editor == nil {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("editor never became available")
                return
            }
            try await Task.sleep(nanoseconds: 25_000_000)
            store.didCompleteRender(parseError: nil, diagramBounds: .zero)
        }
    }

    func test_applyThemeWritesFrontmatterAndPinsPreview() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)

        await store.applyThemeFromToolbar(named: "nord")

        XCTAssertTrue(store.state.source.contains("theme: nord"), "source gains frontmatter theme")
        XCTAssertEqual(store.sourcePinnedThemeName, "nord")
        XCTAssertEqual(store.previewTheme, DiagramTheme.theme(named: "nord"))
    }

    func test_clearThemeRemovesFrontmatter() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)
        await store.applyThemeFromToolbar(named: "nord")

        await store.applyThemeFromToolbar(named: nil)

        XCTAssertFalse(store.state.source.contains("theme:"))
        XCTAssertNil(store.sourcePinnedThemeName)
    }

    func test_applyLayoutPresetWritesAndClearsLayoutKey() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)

        await store.applyLayoutPreset(.adaptive)
        XCTAssertTrue(store.state.source.contains("layout: adaptive"))

        await store.applyLayoutPreset(.hierarchical)
        XCTAssertFalse(store.state.source.contains("layout:"))
    }
}
#endif
