#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import XCTest
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
final class LiveEditorStateVisualZoomTests: XCTestCase {

    func test_visualZoomPan_defaultsNilAndRoundTrips() throws {
        var state = LiveEditorState()
        XCTAssertNil(state.visualZoomScale)
        XCTAssertNil(state.visualPanOffset)

        state.visualZoomScale = 1.75
        state.visualPanOffset = CGSize(width: 12, height: -8)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(LiveEditorState.self, from: data)
        XCTAssertEqual(decoded.visualZoomScale, 1.75)
        XCTAssertEqual(decoded.visualPanOffset, CGSize(width: 12, height: -8))
    }

    func test_visualZoomPan_absentKeysDecodeToNil() throws {
        // A payload from before these fields existed must still decode.
        let legacy = "{}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LiveEditorState.self, from: legacy)
        XCTAssertNil(decoded.visualZoomScale)
        XCTAssertNil(decoded.visualPanOffset)
    }
}
#endif
