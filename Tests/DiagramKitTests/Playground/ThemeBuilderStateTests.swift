//
//  ThemeBuilderStateTests.swift
//  DiagramKitTests
//
//  Phase 10 / Task 10.1 — pin defaults, override get/set, reset,
//  and codec round-trip.
//

import XCTest
@testable import DiagramPlayground

@available(iOS 26.0, macOS 26.0, *)
final class ThemeBuilderStateTests: XCTestCase {

    func test_defaultIsClean() {
        let s = LiveEditorState()
        XCTAssertFalse(s.themeBuilder.dirty)
        XCTAssertNil(s.themeBuilder.override(for: .accent))
    }

    func test_setOverrideMarksDirty() {
        var s = LiveEditorState()
        s.themeBuilder.setOverride(.accent, hex: "112233")
        XCTAssertTrue(s.themeBuilder.dirty)
        XCTAssertEqual(s.themeBuilder.override(for: .accent), "112233")
    }

    func test_setOverrideNilClears() {
        var s = LiveEditorState()
        s.themeBuilder.setOverride(.accent, hex: "112233")
        s.themeBuilder.setOverride(.accent, hex: nil)
        XCTAssertFalse(s.themeBuilder.dirty)
    }

    func test_resetClears() {
        var s = LiveEditorState()
        s.themeBuilder.setOverride(.bg, hex: "AABBCC")
        s.themeBuilder.setOverride(.fg, hex: "112233")
        s.themeBuilder.reset()
        XCTAssertFalse(s.themeBuilder.dirty)
    }

    func test_codecRoundTripOverrides() throws {
        var s = LiveEditorState()
        s.themeBuilder.setOverride(.accent, hex: "FF00FF")
        s.themeBuilder.setOverride(.error, hex: "001122")
        let encoded = LiveEditorStateCodec.encode(s)
        let decoded = try LiveEditorStateCodec.decode(encoded)
        XCTAssertEqual(decoded.themeBuilder.override(for: .accent), "FF00FF")
        XCTAssertEqual(decoded.themeBuilder.override(for: .error), "001122")
    }

    func test_semanticTokensFlagged() {
        XCTAssertTrue(ThemeBuilderState.Token.success.isSemantic)
        XCTAssertTrue(ThemeBuilderState.Token.warning.isSemantic)
        XCTAssertTrue(ThemeBuilderState.Token.error.isSemantic)
        XCTAssertFalse(ThemeBuilderState.Token.bg.isSemantic)
    }

    @MainActor
    func test_storeSettersWriteThrough() {
        let store = LiveEditorStore()
        store.setThemeOverride(.accent, hex: "ABCDEF")
        XCTAssertEqual(store.state.themeBuilder.override(for: .accent), "ABCDEF")
        store.resetThemeOverrides()
        XCTAssertFalse(store.state.themeBuilder.dirty)
    }

    @MainActor
    func test_themeOverridesFlowIntoPreviewTheme() {
        let store = LiveEditorStore()
        let original = store.previewTheme

        store.setThemeOverride(.bg, hex: "112233")
        store.setThemeOverride(.fg, hex: "AABBCC")

        let overridden = store.previewTheme
        XCTAssertFalse(original.background.bmColorEquals(overridden.background))
        XCTAssertFalse(original.foreground.bmColorEquals(overridden.foreground))

        store.resetThemeOverrides()
        XCTAssertTrue(original.background.bmColorEquals(store.previewTheme.background))
    }
}
