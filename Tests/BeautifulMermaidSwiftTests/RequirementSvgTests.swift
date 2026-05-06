import XCTest
@testable import BeautifulMermaid

final class RequirementSvgTests: XCTestCase {

    private func makeBasicDiagram() -> PositionedRequirementDiagram {
        PositionedRequirementDiagram(
            width: 800,
            height: 600,
            nodes: [
                PositionedRequirementNode(
                    id: "test_req", isRequirement: true,
                    requirementType: .requirement, requirementId: "1",
                    text: "the test text.", risk: .high, verifyMethod: .test,
                    elementType: nil, docRef: nil,
                    cssStyles: [], classes: ["default"],
                    x: 100, y: 100, width: 200, height: 120,
                    colorIndex: 0
                ),
                PositionedRequirementNode(
                    id: "test_entity", isRequirement: false,
                    requirementType: nil, requirementId: nil,
                    text: nil, risk: nil, verifyMethod: nil,
                    elementType: "simulation", docRef: nil,
                    cssStyles: [], classes: ["default"],
                    x: 500, y: 100, width: 180, height: 80,
                    colorIndex: 1
                ),
            ],
            edges: [
                PositionedRequirementEdge(
                    id: "test_entity-test_req-0",
                    relationshipType: .satisfies,
                    sourceId: "test_entity",
                    destinationId: "test_req",
                    path: [CGPoint(x: 500, y: 140), CGPoint(x: 300, y: 140)],
                    labelPosition: CGPoint(x: 400, y: 130),
                    labelText: "<<satisfies>>",
                    isDashed: true,
                    startMarker: nil,
                    endMarker: "requirement_arrow"
                ),
            ],
            diagramTitle: nil,
            accTitle: "Accessibility Title",
            accDescr: "Accessibility Description",
            config: RequirementDiagramConfig()
        )
    }

    func testSvgRootElement() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.hasPrefix("<svg"))
        XCTAssertTrue(svg.contains("xmlns=\"http://www.w3.org/2000/svg\""))
        XCTAssertTrue(svg.contains("viewBox=\"0 0 800 600\""))
        XCTAssertTrue(svg.hasSuffix("</svg>"))
    }

    func testAccessibility() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("<title>Accessibility Title</title>"))
        XCTAssertTrue(svg.contains("<desc>Accessibility Description</desc>"))
    }

    func testNodeGroup() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("id=\"node-test_req\""))
        XCTAssertTrue(svg.contains("data-color-id=\"color-0\""))
        XCTAssertTrue(svg.contains("id=\"node-test_entity\""))
        XCTAssertTrue(svg.contains("data-color-id=\"color-1\""))
    }

    func testStereotypeText() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        // Requirement shows <<Requirement>> (XML-escaped as &lt;&lt;Requirement&gt;&gt;)
        XCTAssertTrue(svg.contains("&lt;&lt;Requirement&gt;&gt;") || svg.contains("<<Requirement>>"))
        // Element shows <<Element>>
        XCTAssertTrue(svg.contains("&lt;&lt;Element&gt;&gt;") || svg.contains("<<Element>>"))
    }

    func testBoldNameText() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("font-weight=\"bold\""))
    }

    func testBodyFields() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("ID: 1"))
        XCTAssertTrue(svg.contains("Text: the test text."))
        XCTAssertTrue(svg.contains("Risk: High"))
        XCTAssertTrue(svg.contains("Verification: Test"))
    }

    func testElementBodyFields() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("Type: simulation"))
    }

    func testDividerLine() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("class=\"divider\""))
    }

    func testRelationshipLine() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("class=\"relationshipLine\""))
    }

    func testDashedRelationship() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("stroke-dasharray=\"10,7\""))
    }

    func testMarkerDefs() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("id=\"requirement_contains\""))
        XCTAssertTrue(svg.contains("id=\"requirement_arrow\""))
    }

    func testArrowMarkerReference() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("marker-end=\"url(#requirement_arrow)\""))
    }

    func testEdgeLabel() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("&lt;&lt;satisfies&gt;&gt;") || svg.contains("<<satisfies>>"))
    }

    func testStyleBlock() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("<style>"))
        XCTAssertTrue(svg.contains("</style>"))
    }

    func testUseMaxWidth() throws {
        var config = RequirementDiagramConfig()
        config.useMaxWidth = true
        var diagram = makeBasicDiagram()
        diagram.config = config
        let svg = try renderRequirementSvg(diagram, DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("width=\"100%\""))
    }
}
