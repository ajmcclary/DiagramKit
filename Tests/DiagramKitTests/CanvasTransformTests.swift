#if canImport(CoreGraphics)
import CoreGraphics
import XCTest
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
final class CanvasTransformTests: XCTestCase {

    private let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    private let view = CGSize(width: 400, height: 300)

    func test_identity_diagramPoint_matchesCenteringOffset() {
        // scale 1, no pan: diagram is centered; centering offset = (150, 100).
        // A tap at (170, 110) → (20, 10) in diagram-space.
        let t = CanvasTransform(scale: 1, offset: .zero)
        let p = t.diagramPoint(fromViewPoint: CGPoint(x: 170, y: 110),
                               diagramBounds: bounds, viewSize: view)
        XCTAssertEqual(p.x, 20, accuracy: 0.0001)
        XCTAssertEqual(p.y, 10, accuracy: 0.0001)
    }

    func test_zoomAndPan_diagramPoint_invertsForwardTransform() {
        // scale 2, pan (30, 20). Scaled 200x200, centering (100, 50),
        // origin = (130, 70). Tap (170, 90) → screen delta (40, 20) / 2 = (20, 10).
        let t = CanvasTransform(scale: 2, offset: CGSize(width: 30, height: 20))
        let p = t.diagramPoint(fromViewPoint: CGPoint(x: 170, y: 90),
                               diagramBounds: bounds, viewSize: view)
        XCTAssertEqual(p.x, 20, accuracy: 0.0001)
        XCTAssertEqual(p.y, 10, accuracy: 0.0001)
    }

    func test_viewRect_isInverseOfDiagramPoint() {
        // Forward then inverse must round-trip the element origin.
        let t = CanvasTransform(scale: 1.5, offset: CGSize(width: -12, height: 8))
        let element = CGRect(x: 20, y: 10, width: 40, height: 30)
        let rect = t.viewRect(forDiagramBounds: element, diagramBounds: bounds, viewSize: view)
        let backToDiagram = t.diagramPoint(fromViewPoint: CGPoint(x: rect.minX, y: rect.minY),
                                           diagramBounds: bounds, viewSize: view)
        XCTAssertEqual(backToDiagram.x, element.minX, accuracy: 0.0001)
        XCTAssertEqual(backToDiagram.y, element.minY, accuracy: 0.0001)
        XCTAssertEqual(rect.width, element.width * 1.5, accuracy: 0.0001)
        XCTAssertEqual(rect.height, element.height * 1.5, accuracy: 0.0001)
    }

    func test_clampScale_boundsToMinAndMax() {
        XCTAssertEqual(CanvasTransform.clampScale(0.1), 0.25, accuracy: 0.0001)
        XCTAssertEqual(CanvasTransform.clampScale(9), 4.0, accuracy: 0.0001)
        XCTAssertEqual(CanvasTransform.clampScale(1.5), 1.5, accuracy: 0.0001)
    }

    func test_fitScale_usesTightestAxisWithMargin() {
        // 100x100 in 400x300 with margin 0.92: min(400*.92/100, 300*.92/100)
        // = min(3.68, 2.76) = 2.76.
        let s = CanvasTransform.fitScale(diagramBounds: bounds, viewSize: view)
        XCTAssertEqual(s, 2.76, accuracy: 0.0001)
    }

    func test_gestureScale_multipliesAndClamps() {
        XCTAssertEqual(CanvasTransform.gestureScale(base: 1, value: 2), 2, accuracy: 0.0001)
        XCTAssertEqual(CanvasTransform.gestureScale(base: 3, value: 2), 4.0, accuracy: 0.0001) // clamped
    }
}
#endif
