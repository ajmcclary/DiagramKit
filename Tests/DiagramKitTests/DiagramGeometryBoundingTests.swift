import Testing
import DiagramKitCommon

@Suite("DiagramRect.bounding")
struct DiagramGeometryBoundingTests {

    @Test("Empty point list returns .zero")
    func emptyReturnsZero() {
        let rect = DiagramRect.bounding(points: [DiagramPoint](), paddedBy: 8)
        #expect(rect == .zero)
    }

    @Test("Single point with zero pad collapses to a zero-size rect")
    func singlePointZeroPad() {
        let rect = DiagramRect.bounding(points: [DiagramPoint(x: 10, y: 20)], paddedBy: 0)
        #expect(rect.x == 10)
        #expect(rect.y == 20)
        #expect(rect.width == 0)
        #expect(rect.height == 0)
    }

    @Test("Multi-point with positive pad expands the bounding box")
    func multiPointPositivePad() {
        let points = [
            DiagramPoint(x: 10, y: 20),
            DiagramPoint(x: 50, y: 5),
            DiagramPoint(x: 30, y: 80)
        ]
        let rect = DiagramRect.bounding(points: points, paddedBy: 8)
        #expect(rect.x == 10 - 8)
        #expect(rect.y == 5 - 8)
        #expect(rect.width == (50 - 10) + 16)
        #expect(rect.height == (80 - 5) + 16)
    }

    @Test("Default pad is zero")
    func defaultPadIsZero() {
        let rect = DiagramRect.bounding(points: [
            DiagramPoint(x: 0, y: 0),
            DiagramPoint(x: 100, y: 50)
        ])
        #expect(rect.x == 0)
        #expect(rect.y == 0)
        #expect(rect.width == 100)
        #expect(rect.height == 50)
    }
}
