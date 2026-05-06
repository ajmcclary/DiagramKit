import XCTest
@testable import BeautifulMermaid

final class RequirementRendererTests: XCTestCase {

    func testFullPipelineParseAndLayout() throws {
        let source = """
        requirementDiagram
        requirement test_req {
        id: 1
        text: the test text.
        risk: high
        verifymethod: test
        }
        element test_entity {
        type: simulation
        }
        test_entity - satisfies -> test_req
        """

        let graph = try MermaidParser.parse(source)
        XCTAssertEqual(graph.type, .requirement)

        let positioned = try GraphLayout().layout(graph)
        XCTAssertGreaterThan(positioned.width, 0)

        // Check that content is requirement type
        guard case .requirement(let diagram) = positioned.content else {
            XCTFail("Expected requirement content")
            return
        }
        XCTAssertGreaterThanOrEqual(diagram.nodes.count, 2)
        XCTAssertGreaterThanOrEqual(diagram.edges.count, 1)
    }

    func testFullPipelineSvg() async throws {
        let source = """
        requirementDiagram
        requirement test_req {
        id: 1
        text: the test text.
        risk: high
        verifymethod: test
        }
        element test_entity {
        type: simulation
        }
        test_entity - satisfies -> test_req
        """

        let svg = try await renderMermaidSVG(source)
        XCTAssertTrue(svg.hasPrefix("<svg"))
        XCTAssertTrue(svg.hasSuffix("</svg>"))
        XCTAssertTrue(svg.contains("class=\"relationshipLine\""))
    }

    func testRenderAsync() async throws {
        let source = """
        requirementDiagram
        requirement A {
        id: 1
        text: test
        risk: low
        verifymethod: inspection
        }
        requirement B {
        id: 2
        text: test2
        risk: medium
        verifymethod: demonstration
        }
        A - satisfies -> B
        """

        let svg = try await renderMermaidSVG(source)
        XCTAssertTrue(svg.contains("&lt;&lt;satisfies&gt;&gt;") || svg.contains("<<satisfies>>"))
        XCTAssertTrue(svg.contains("Risk: Low"))
        XCTAssertTrue(svg.contains("Risk: Medium"))
        XCTAssertTrue(svg.contains("Verification: Inspection"))
        XCTAssertTrue(svg.contains("Verification: Demonstration"))
    }

    func testAllRelationshipTypes() async throws {
        let source = """
        requirementDiagram
        requirement A {
        id: 1
        }
        requirement B {
        id: 2
        }
        A - contains -> B
        A - copies -> B
        A - derives -> B
        A - satisfies -> B
        A - verifies -> B
        A - refines -> B
        A - traces -> B
        """

        let svg = try await renderMermaidSVG(source)
        for type in RequirementRelationshipType.allCases {
            let escaped = "&lt;&lt;\(type.rawValue)&gt;&gt;"
            let unescaped = "<<\(type.rawValue)>>"
            XCTAssertTrue(svg.contains(escaped) || svg.contains(unescaped), "Missing relationship label for: \(type.rawValue)")
        }
    }

    func testEmptyFieldsOmitted() async throws {
        let source = """
        requirementDiagram
        requirement X {
        }
        """

        let svg = try await renderMermaidSVG(source)
        // With no fields, there should be no divider line
        // Just verify it renders without error
        XCTAssertTrue(svg.contains("node-X"))
    }
}
