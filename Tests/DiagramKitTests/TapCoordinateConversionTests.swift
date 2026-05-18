#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import XCTest
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
final class TapCoordinateConversionTests: XCTestCase {

    func test_identityTransformReturnsTapMinusCenteringOffset() {
        // viewSize 400x300, diagramBounds 100x100, no zoom, no pan.
        // The diagram is centered, so the centering offset on each axis is
        // (viewSize - diagramSize)/2 = (150, 100).
        // A tap at (170, 110) lands at (20, 10) in diagram-coords.
        let point = LiveEditorStore.tapPointInDiagramCoordinates(
            viewPoint: CGPoint(x: 170, y: 110),
            viewSize: CGSize(width: 400, height: 300),
            diagramBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            zoomScale: 1,
            panOffset: .zero
        )
        XCTAssertEqual(point.x, 20, accuracy: 0.0001)
        XCTAssertEqual(point.y, 10, accuracy: 0.0001)
    }

    func test_zoomScaleDividesOutOfTapCoordinates() {
        // viewSize 400x300, diagramBounds 100x100, zoom 2x.
        // Scaled diagram is 200x200, centered at offset ((400-200)/2, (300-200)/2) = (100, 50).
        // A tap at (140, 70) is (40, 20) in screen-px from the diagram origin;
        // divided by zoom 2 gives (20, 10) in diagram-coords.
        let point = LiveEditorStore.tapPointInDiagramCoordinates(
            viewPoint: CGPoint(x: 140, y: 70),
            viewSize: CGSize(width: 400, height: 300),
            diagramBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            zoomScale: 2,
            panOffset: .zero
        )
        XCTAssertEqual(point.x, 20, accuracy: 0.0001)
        XCTAssertEqual(point.y, 10, accuracy: 0.0001)
    }

    func test_panOffsetSubtractsBeforeZoomDivision() {
        // viewSize 400x300, diagramBounds 100x100, zoom 2x, pan (30, 20).
        // Centering offset (100, 50). Effective draw origin = (130, 70).
        // A tap at (170, 90) is (40, 20) in screen-px → (20, 10) in diagram.
        let point = LiveEditorStore.tapPointInDiagramCoordinates(
            viewPoint: CGPoint(x: 170, y: 90),
            viewSize: CGSize(width: 400, height: 300),
            diagramBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            zoomScale: 2,
            panOffset: CGSize(width: 30, height: 20)
        )
        XCTAssertEqual(point.x, 20, accuracy: 0.0001)
        XCTAssertEqual(point.y, 10, accuracy: 0.0001)
    }
}
#endif
