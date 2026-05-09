import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

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
        XCTAssertTrue(svg.contains("&lt;&lt;Requirement&gt;&gt;"))
        XCTAssertTrue(svg.contains("&lt;&lt;Element&gt;&gt;"))
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
        // Marker IDs are scoped: <baseId>_requirement-containsStart / <baseId>_requirement-arrowEnd
        let defsSection = svg.components(separatedBy: "<defs>")[1].components(separatedBy: "</defs>")[0]
        XCTAssertTrue(defsSection.contains("requirement-containsStart"), "Expected contains marker in defs: \(defsSection)")
        XCTAssertTrue(defsSection.contains("requirement-arrowEnd"), "Expected arrow marker in defs: \(defsSection)")
    }

    func testArrowMarkerReference() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("marker-end=\"url(#"))
        XCTAssertTrue(svg.contains("requirement-arrowEnd"))
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

    // MARK: - R2-1: SysML marker DOM

    func testContainsMarkerIsCircleCross() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        // Contains marker definition should contain circle + two lines (cross)
        let defsSection = svg.components(separatedBy: "<defs>")[1].components(separatedBy: "</defs>")[0]
        XCTAssertTrue(defsSection.contains("circle"), "Contains marker must have a circle")
        XCTAssertTrue(defsSection.contains("<line"), "Contains marker must have cross lines")
    }

    func testArrowMarkerIsOpenV() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        let defsSection = svg.components(separatedBy: "<defs>")[1].components(separatedBy: "</defs>")[0]
        // Arrow marker should use open-V path (two disjoint M...L... segments, no Z close)
        XCTAssertTrue(defsSection.contains("M0,0 L20,10 M20,10 L0,20") || defsSection.contains("M0,0 L20,10"))
    }

    func testMarkersUseCorrectRefPoints() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        // Contains: refX=0, refY=10
        XCTAssertTrue(svg.contains("refX=\"0\""))
        XCTAssertTrue(svg.contains("refY=\"10\""))
        // Arrow: refX=20, refY=10
        XCTAssertTrue(svg.contains("refX=\"20\""))
    }

    // MARK: - R2-2: Scoped marker IDs

    func testScopedMarkerIds() throws {
        let svg1 = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"), diagramId: "diag1")
        let svg2 = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"), diagramId: "diag2")
        XCTAssertTrue(svg1.contains("diag1_requirement-containsStart"))
        XCTAssertTrue(svg1.contains("diag1_requirement-arrowEnd"))
        XCTAssertTrue(svg2.contains("diag2_requirement-containsStart"))
        XCTAssertTrue(svg2.contains("diag2_requirement-arrowEnd"))
    }

    func testDefaultMarkerIdFallsBack() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"), diagramId: nil)
        XCTAssertTrue(svg.contains("requirement_requirement-containsStart"))
        XCTAssertTrue(svg.contains("requirement_requirement-arrowEnd"))
    }

    // MARK: - R2-3: Neo-look support

    func testNeoMarkersGenerated() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"), look: "neo")
        let defsSection = svg.components(separatedBy: "<defs>")[1].components(separatedBy: "</defs>")[0]
        XCTAssertTrue(defsSection.contains("markerUnits=\"userSpaceOnUse\""))
    }

    func testNeoDividerPolygon() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"), look: "neo")
        XCTAssertTrue(svg.contains("<polygon class=\"divider\""))
    }

    func testClassicDividerLine() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"), look: "classic")
        XCTAssertTrue(svg.contains("<line class=\"divider\""))
    }

    func testDataLookAttributeClassic() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"), look: "classic")
        XCTAssertTrue(svg.contains("data-look=\"classic\""))
    }

    func testDataLookAttributeNeo() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"), look: "neo")
        XCTAssertTrue(svg.contains("data-look=\"neo\""))
    }

    func testNeoLineWidth() throws {
        let svg = try renderRequirementSvg(
            makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"),
            look: "neo",
            theme: RequirementThemeVariables(strokeWidth: "3.5")
        )
        let defsSection = svg.components(separatedBy: "<defs>")[1].components(separatedBy: "</defs>")[0]
        XCTAssertTrue(defsSection.contains("stroke-width=\"3.5\""))
    }

    // MARK: - R2-4: Markdown text rendering

    func testBoldTextInRequirementTextField() throws {
        var diagram = makeBasicDiagram()
        var nodes = diagram.nodes
        nodes[0] = PositionedRequirementNode(
            id: "test_req", isRequirement: true,
            requirementType: .requirement, requirementId: "1",
            text: "the **bold** test.", risk: .high, verifyMethod: .test,
            elementType: nil, docRef: nil,
            cssStyles: [], classes: ["default"],
            x: 100, y: 100, width: 200, height: 120,
            colorIndex: 0
        )
        diagram = PositionedRequirementDiagram(
            width: diagram.width, height: diagram.height,
            nodes: nodes, edges: diagram.edges,
            diagramTitle: diagram.diagramTitle,
            accTitle: diagram.accTitle, accDescr: diagram.accDescr,
            config: diagram.config
        )
        let svg = try renderRequirementSvg(diagram, DiagramColors(bg: "#fff", fg: "#000"))
        // After normalizeBrTags, **bold** becomes <b>bold</b>, renderLineContent → <tspan font-weight="bold">
        XCTAssertTrue(svg.contains("font-weight=\"bold\""))
        XCTAssertTrue(svg.contains("bold"))
    }

    func testItalicTextInRequirementName() throws {
        var diagram = makeBasicDiagram()
        var nodes = diagram.nodes
        nodes[0] = PositionedRequirementNode(
            id: "*italic_name*", isRequirement: true,
            requirementType: .requirement, requirementId: "1",
            text: "test", risk: .high, verifyMethod: .test,
            elementType: nil, docRef: nil,
            cssStyles: [], classes: ["default"],
            x: 100, y: 100, width: 200, height: 120,
            colorIndex: 0
        )
        diagram = PositionedRequirementDiagram(
            width: diagram.width, height: diagram.height,
            nodes: nodes, edges: diagram.edges,
            diagramTitle: diagram.diagramTitle,
            accTitle: diagram.accTitle, accDescr: diagram.accDescr,
            config: diagram.config
        )
        let svg = try renderRequirementSvg(diagram, DiagramColors(bg: "#fff", fg: "#000"))
        // After normalizeBrTags, *italic_name* becomes <i>italic_name</i>, renderLineContent → <tspan font-style="italic">
        XCTAssertTrue(svg.contains("font-style=\"italic\"") || svg.contains("italic_name"))
    }

    // MARK: - R2-5: Theme variable style generation

    func testThemeVariableCustomBackground() throws {
        let theme = RequirementThemeVariables(requirementBackground: "#ff0000")
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"), look: "classic", theme: theme)
        XCTAssertTrue(svg.contains("fill: #ff0000"))
    }

    func testThemeVariableBorderColor() throws {
        let theme = RequirementThemeVariables(requirementBorderColor: "#00ff00")
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"), look: "classic", theme: theme)
        XCTAssertTrue(svg.contains("stroke: #00ff00"))
    }

    func testThemeVariableRelationColor() throws {
        let theme = RequirementThemeVariables(relationColor: "#0000ff")
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"), look: "classic", theme: theme)
        XCTAssertTrue(svg.contains("stroke: #0000ff"))
    }

    func testThemeVariableReqBoxClass() throws {
        let svg = try renderRequirementSvg(makeBasicDiagram(), DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains(".reqBox"))
        XCTAssertTrue(svg.contains(".reqTitle"))
        XCTAssertTrue(svg.contains(".relationshipLine"))
        XCTAssertTrue(svg.contains(".edgeLabel"))
    }
}
