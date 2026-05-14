import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class WardleyMapLayoutTests: XCTestCase {
    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n").map(String.init)
    }

    private func distance(_ a: (x: Double, y: Double), _ b: (x: Double, y: Double)) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    func testPipelineParentLinksAndTrendsUseRepositionedParent() throws {
        let source = [
            "wardley-beta",
            "component Database [0.50, 0.75]",
            "component Cache [0.55, 0.70]",
            "pipeline Database {",
            "  component PostgreSQL [0.35]",
            "  component DynamoDB [0.85]",
            "}",
            "Cache -> Database",
            "evolve Database 0.80",
        ].joined(separator: "\n")

        let (diagram, _) = try parseWardleyMap(lines(source))
        let positioned = layoutWardleyMap(diagram)
        let parent = try XCTUnwrap(positioned.nodes.first { $0.id == "Database" && $0.isPipelineParent })
        let link = try XCTUnwrap(positioned.validLinks.first { $0.target == "Database" })
        let trend = try XCTUnwrap(positioned.trends.first { $0.nodeId == "Database" })

        let parentEdgeTolerance = diagram.config.nodeRadius * 1.6 / sqrt(2) + 1
        XCTAssertLessThanOrEqual(
            distance((link.targetX, link.targetY), (parent.x, parent.y)),
            parentEdgeTolerance
        )
        XCTAssertEqual(trend.originX, parent.x, accuracy: 0.001)
        XCTAssertEqual(trend.originY, parent.y, accuracy: 0.001)
    }
}
