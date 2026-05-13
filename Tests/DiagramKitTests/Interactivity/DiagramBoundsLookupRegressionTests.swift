import XCTest
import DiagramKit
import DiagramKitCommon
import DiagramKitModel

final class DiagramBoundsLookupRegressionTests: XCTestCase {
    func testStateDiagramLookupSelectionsPreserveStateDiagramType() async throws {
        let source = """
        stateDiagram-v2
          [*] --> Idle
          Idle --> Running
        """

        let positioned = try await DiagramEngine.layout(source)
        let idle = try XCTUnwrap(positioned.flowchartNodes?.first { $0.id == "Idle" })

        let selection = positioned.lookup.element(
            at: DiagramPoint(x: idle.x + idle.width / 2, y: idle.y + idle.height / 2)
        )

        XCTAssertEqual(selection?.diagramType, .stateDiagram)
        XCTAssertEqual(selection?.elementID, "node:Idle")
    }

    func testElementKindPriorityBeatsAppendOrderForHitTesting() {
        let group = LookupTestElement(
            id: "group:outer",
            bounds: DiagramRect(x: 0, y: 0, width: 120, height: 120),
            label: "Outer"
        )
        let node = LookupTestElement(
            id: "node:inner",
            bounds: DiagramRect(x: 40, y: 40, width: 40, height: 40),
            label: "Inner"
        )

        let lookup = DiagramBoundsLookup.build(
            diagramType: .flowchart,
            elements: [
                (node, kind: .node),
                (group, kind: .group),
            ]
        )

        let selection = lookup.element(at: DiagramPoint(x: 60, y: 60))
        XCTAssertEqual(selection?.elementID, "node:inner")
    }

    func testXYChartStableIDsSurviveSizeDrivenRelayout() {
        let small = xyChart(width: 500, height: 320)
        let large = xyChart(width: 900, height: 640)

        XCTAssertEqual(lookupIDs(for: small), lookupIDs(for: large))
    }

    func testZenUMLMessageStableIDIgnoresLayoutCoordinates() {
        let first = PositionedZenUMLMessage(
            fromX: 80,
            toX: 220,
            y: 100,
            label: "request",
            arrowStyle: .solid,
            isSelf: false,
            isReverse: false,
            number: "1"
        )
        let second = PositionedZenUMLMessage(
            fromX: 120,
            toX: 420,
            y: 160,
            label: "request",
            arrowStyle: .solid,
            isSelf: false,
            isReverse: false,
            number: "1"
        )

        XCTAssertEqual(first.stableElementID, second.stableElementID)
    }

    private func xyChart(width: Double, height: Double) -> XYChart {
        XYChart(
            title: "Revenue",
            xAxis: XYAxis(categories: ["Q1", "Q2", "Q3"]),
            yAxis: XYAxis(range: (min: 0, max: 10), kind: .linear),
            series: [
                XYChartSeries(type: .bar, title: XYText(text: "Actual"), data: [2, 4, 6]),
                XYChartSeries(type: .line, title: XYText(text: "Target"), data: [3, 5, 7]),
            ],
            config: XYChartConfig(width: width, height: height)
        )
    }

    private func lookupIDs(for chart: XYChart) -> [String] {
        let positioned = layoutXYChart(chart)
        let graph = PositionedGraph(
            diagram: DiagramDocument(payload: .xyChart(chart)),
            width: positioned.width,
            height: positioned.height,
            content: .xyChart(positioned)
        )
        return graph.lookup.allElementIDs
    }
}

private struct LookupTestElement: DiagramStableElement {
    var id: String
    var bounds: DiagramRect
    var label: String?

    var stableElementID: String { id }
    var stableElementBounds: DiagramRect { bounds }
    var stableElementLabel: String? { label }
}
