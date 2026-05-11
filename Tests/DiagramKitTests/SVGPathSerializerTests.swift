#if canImport(CoreGraphics)
import XCTest
@testable import DiagramKitModel

/// Guards against the audit's "SVG silently degrades complex shapes to
/// rectangles" risk. Every `ShapePath` case must produce non-empty path
/// data that contains at least one drawing command beyond `M` (so a
/// degenerate "M 0 0 Z" stub fails the test). If a new `ShapePath` case
/// is added without a matching serializer branch, this test fails by
/// design (Swift's exhaustive switch in the serializer would catch it
/// first, but the test keeps the regression-coverage explicit).
final class SVGPathSerializerTests: XCTestCase {

    private let bounds = CGRect(x: 0, y: 0, width: 100, height: 60)

    private func assertNonTrivial(_ shapePath: ShapePath, file: StaticString = #filePath, line: UInt = #line) {
        let data = SVGPathSerializer.serialize(shapePath, in: bounds)
        XCTAssertFalse(data.isEmpty, "empty path data for \(shapePath)", file: file, line: line)
        XCTAssertTrue(data.contains("M"), "no Move command for \(shapePath): \(data)", file: file, line: line)
        let hasDrawingCommand = data.contains("L") || data.contains("C") || data.contains("Q") || data.contains("A")
        XCTAssertTrue(hasDrawingCommand,
                      "no drawing command (L/C/Q/A) for \(shapePath): \(data)",
                      file: file, line: line)
    }

    func test_rectAndRoundedRect() {
        assertNonTrivial(.rect(cornerRadius: 0))
        assertNonTrivial(.rect(cornerRadius: 8))
    }

    func test_basicShapes() {
        assertNonTrivial(.ellipse)
        assertNonTrivial(.diamond)
        assertNonTrivial(.hexagon)
        assertNonTrivial(.stadium)
        assertNonTrivial(.cylinder(topCapInset: 8))
        assertNonTrivial(.trapezoid(skew: 0.3))
        assertNonTrivial(.parallelogram(skew: 0.3))
    }

    func test_complexShapesNoLongerDegradeToRectangles() {
        // These cases all hit the legacy rectangle fallback before the
        // serializer was completed. Now they each produce a distinct path.
        assertNonTrivial(.subroutine(inset: 6))
        assertNonTrivial(.doubleCircle(gap: 5))
        assertNonTrivial(.asymmetric(indent: 8))
        assertNonTrivial(.crossedCircle)
        assertNonTrivial(.hourglass)
        assertNonTrivial(.lightningBolt)
        assertNonTrivial(.cloud)
        assertNonTrivial(.bowTie(indent: 12))
        assertNonTrivial(.triangle)
        assertNonTrivial(.flag)
        assertNonTrivial(.document)
    }

    func test_polygonProducesVertexList() {
        let triangle: ShapePath = .polygon(vertices: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 50, y: 60),
        ])
        let data = SVGPathSerializer.serialize(triangle, in: bounds)
        XCTAssertTrue(data.contains("M 0 0"))
        XCTAssertTrue(data.contains("L 100 0") || data.contains("L 100"))
        XCTAssertTrue(data.contains("L 50 60") || data.contains("L 50"))
        XCTAssertTrue(data.hasSuffix("Z"))
    }

    func test_complexShapesProduceDistinctPaths() {
        // Two complex shapes should not yield byte-identical strings —
        // that's the regression the audit warned about (rectangle fallback
        // collapsed many shapes into the same path).
        let cloud = SVGPathSerializer.serialize(.cloud, in: bounds)
        let hourglass = SVGPathSerializer.serialize(.hourglass, in: bounds)
        let triangle = SVGPathSerializer.serialize(.triangle, in: bounds)
        let document = SVGPathSerializer.serialize(.document, in: bounds)
        XCTAssertNotEqual(cloud, hourglass)
        XCTAssertNotEqual(cloud, triangle)
        XCTAssertNotEqual(cloud, document)
        XCTAssertNotEqual(hourglass, triangle)
        XCTAssertNotEqual(hourglass, document)
        XCTAssertNotEqual(triangle, document)
    }
}
#endif
