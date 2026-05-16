import XCTest
@testable import DiagramKit
@testable import DiagramKitModel

final class PositionedContentCountsTests: XCTestCase {

    func testFlowchartCountsMatchSource() throws {
        let source = """
        graph TD
            A --> B
            B --> C
            C --> D
        """
        let graph = try DiagramPipeline.layout(source)
        XCTAssertEqual(graph.nodeCount, 4, "expected A, B, C, D")
        XCTAssertEqual(graph.edgeCount, 3, "expected three --> edges")
    }

    func testStateDiagramCounts() throws {
        let source = """
        stateDiagram-v2
            [*] --> Idle
            Idle --> Running
            Running --> Idle
        """
        let graph = try DiagramPipeline.layout(source)
        XCTAssertGreaterThanOrEqual(graph.nodeCount, 2)
        XCTAssertGreaterThanOrEqual(graph.edgeCount, 1)
    }

    func testEmptyFallbackForUncoveredFamilies() throws {
        let source = """
        pie title Sample
            "A" : 30
            "B" : 70
        """
        let graph = try DiagramPipeline.layout(source)
        // Pie is not in the covered set; the API contract is that
        // uncovered families return 0 rather than crashing.
        XCTAssertEqual(graph.nodeCount, 0)
        XCTAssertEqual(graph.edgeCount, 0)
    }
}
