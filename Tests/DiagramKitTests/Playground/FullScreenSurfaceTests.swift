//
//  FullScreenSurfaceTests.swift
//  DiagramKitTests
//
//  Phase 8 / Task 8.1 — FullScreenSurface enum + state field +
//  store helpers.
//

import XCTest
@testable import DiagramPlayground

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class FullScreenSurfaceTests: XCTestCase {

    func test_allCasesIncludesNoneAndFiveSurfaces() {
        XCTAssertEqual(FullScreenSurface.allCases.count, 6)
    }

    func test_defaultIsNone() {
        let s = LiveEditorState()
        XCTAssertEqual(s.fullScreen, .none)
    }

    func test_codecRoundTripPreservesFullScreen() throws {
        var s = LiveEditorState()
        s.fullScreen = .corpus
        let encoded = LiveEditorStateCodec.encode(s)
        let decoded = try LiveEditorStateCodec.decode(encoded)
        XCTAssertEqual(decoded.fullScreen, .corpus)
    }

    @MainActor
    func test_storeSettersWriteThrough() {
        let store = LiveEditorStore()
        store.setFullScreen(.coverage)
        XCTAssertEqual(store.state.fullScreen, .coverage)
        store.dismissFullScreen()
        XCTAssertEqual(store.state.fullScreen, .none)
    }
}
