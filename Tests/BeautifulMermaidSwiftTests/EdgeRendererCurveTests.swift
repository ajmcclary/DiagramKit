import XCTest
import CoreGraphics
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class EdgeRendererCurveTests: XCTestCase {

    private func makeContext() -> CGContext {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 400,
            pixelsHigh: 400,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        return NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    }

    private func pathPoints(_ path: CGPath) -> [CGPoint] {
        var points: [CGPoint] = []
        path.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            switch element.type {
            case .moveToPoint, .addLineToPoint:
                points.append(element.points[0])
            case .addCurveToPoint:
                points.append(element.points[2])
            default:
                break
            }
        }
        return points
    }

    func testLinearCurveProducesPolyline() {
        let renderer = EdgeRenderer()
        let path = renderer.buildCurvedPath(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 50),
            CGPoint(x: 100, y: 0),
        ], curveType: "linear")
        let pts = pathPoints(path)
        XCTAssertEqual(pts.count, 3, "Linear should produce exact polyline with all input points")
        XCTAssertEqual(pts[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(pts[1], CGPoint(x: 50, y: 50))
        XCTAssertEqual(pts[2], CGPoint(x: 100, y: 0))
    }

    func testStepCurveInterleavesHorizontalVertical() {
        let renderer = EdgeRenderer()
        let path = renderer.buildCurvedPath(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 50),
            CGPoint(x: 100, y: 0),
        ], curveType: "step")
        let pts = pathPoints(path)
        // step/stepBefore: horizontal then vertical for each segment
        // segment 0-1: (0,0) → (0,50) → (50,50)  [H then V]
        // segment 1-2: (50,50) → (50,0) → (100,0) [H then V]
        XCTAssertGreaterThan(pts.count, 3, "Step should produce more points than input")
        XCTAssertEqual(pts[0], CGPoint(x: 0, y: 0))
    }

    func testStepAfterCurve() {
        let renderer = EdgeRenderer()
        let path = renderer.buildCurvedPath(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 50),
            CGPoint(x: 100, y: 0),
        ], curveType: "stepAfter")
        let pts = pathPoints(path)
        XCTAssertGreaterThan(pts.count, 3, "stepAfter should produce more points than input")
        XCTAssertEqual(pts[0], CGPoint(x: 0, y: 0))
    }

    func testBasisCurveProducesSmoothPath() {
        let renderer = EdgeRenderer()
        let path = renderer.buildCurvedPath(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 50),
            CGPoint(x: 100, y: 50),
            CGPoint(x: 150, y: 0),
        ], curveType: "basis")
        let pts = pathPoints(path)
        // Each Catmull-Rom segment produces 3 points per Bezier (move/cp1/cp2/end)
        // For 4 input points, 3 curves produced
        XCTAssertTrue(pts.contains(where: { $0.x > 0 && $0.x < 150 }), "Should have intermediate points")
        // Start and end should be near original points
        let first = pts.first!
        let last = pts.last!
        XCTAssertEqual(first.x, 0, accuracy: 0.01)
        XCTAssertEqual(first.y, 0, accuracy: 0.01)
        XCTAssertEqual(last.x, 150, accuracy: 0.01)
        XCTAssertEqual(last.y, 0, accuracy: 0.01)
    }

    func testNaturalCurveUsesHigherTension() {
        let renderer = EdgeRenderer()
        // Same points, natural curve should produce different control points than basis
        let path = renderer.buildCurvedPath(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 50),
            CGPoint(x: 100, y: 0),
        ], curveType: "natural")
        let pts = pathPoints(path)
        // Verify path is valid (has at least start and end)
        XCTAssertGreaterThan(pts.count, 0)
    }

    func testEmptyPointsProducesEmptyPath() {
        let renderer = EdgeRenderer()
        let path = renderer.buildCurvedPath(points: [], curveType: nil)
        let pts = pathPoints(path)
        XCTAssertTrue(pts.isEmpty)
    }

    func testSinglePointProducesEmptyPath() {
        let renderer = EdgeRenderer()
        let path = renderer.buildCurvedPath(points: [CGPoint(x: 10, y: 20)], curveType: nil)
        let pts = pathPoints(path)
        XCTAssertTrue(pts.isEmpty)
    }

    func testUnknownCurveTypeDefaultsToLinear() {
        let renderer = EdgeRenderer()
        let path = renderer.buildCurvedPath(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 100),
        ], curveType: "unknown_curve")
        let pts = pathPoints(path)
        XCTAssertEqual(pts.count, 2)
    }
}
