import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class RequirementLayoutTests: XCTestCase {

    func testNodesPositioned() throws {
        let diagram = RequirementDiagram(
            requirements: [
                RequirementNode(name: "R1", type: .requirement, requirementId: "1", text: "test", risk: .high, verifyMethod: .test, cssStyles: [], classes: ["default"], sourceOrder: 0),
                RequirementNode(name: "R2", type: .functionalRequirement, requirementId: "2", text: "test2", risk: .low, verifyMethod: nil, cssStyles: [], classes: ["default"], sourceOrder: 1),
            ],
            elements: [
                ElementNode(name: "E1", type: "simulation", docRef: "doc1", cssStyles: [], classes: ["default"], sourceOrder: 2),
            ],
            relationships: [],
            classDefs: [],
            direction: .TB,
            config: RequirementDiagramConfig()
        )

        let positioned = try layoutRequirementDiagram(diagram)
        XCTAssertGreaterThan(positioned.nodes.count, 0)
        for node in positioned.nodes {
            XCTAssertGreaterThan(node.width, 0)
            XCTAssertGreaterThan(node.height, 0)
        }
    }

    func testRequirmentsBeforeElementsColorIndex() throws {
        let diagram = RequirementDiagram(
            requirements: [
                RequirementNode(name: "R1", type: .requirement, requirementId: "1", text: "t", risk: nil, verifyMethod: nil, cssStyles: [], classes: ["default"], sourceOrder: 0),
                RequirementNode(name: "R2", type: .functionalRequirement, requirementId: "2", text: "t", risk: nil, verifyMethod: nil, cssStyles: [], classes: ["default"], sourceOrder: 1),
            ],
            elements: [
                ElementNode(name: "E1", type: "sim", docRef: "", cssStyles: [], classes: ["default"], sourceOrder: 2),
                ElementNode(name: "E2", type: "test", docRef: "", cssStyles: [], classes: ["default"], sourceOrder: 3),
            ],
            relationships: [],
            classDefs: [],
            direction: .TB,
            config: RequirementDiagramConfig()
        )

        let positioned = try layoutRequirementDiagram(diagram)
        // Requirements get 0..N-1, elements get N..N+M-1
        for node in positioned.nodes {
            if node.isRequirement {
                XCTAssertLessThan(node.colorIndex, 2)
            } else {
                XCTAssertGreaterThanOrEqual(node.colorIndex, 2)
            }
        }
    }

    func testEdgePaths() throws {
        let diagram = RequirementDiagram(
            requirements: [
                RequirementNode(name: "A", type: .requirement, requirementId: "1", text: "t", risk: nil, verifyMethod: nil, cssStyles: [], classes: ["default"], sourceOrder: 0),
                RequirementNode(name: "B", type: .requirement, requirementId: "2", text: "t", risk: nil, verifyMethod: nil, cssStyles: [], classes: ["default"], sourceOrder: 1),
            ],
            elements: [],
            relationships: [
                RequirementRelationship(type: .satisfies, sourceName: "A", destinationName: "B", isReversed: false),
            ],
            classDefs: [],
            direction: .TB,
            config: RequirementDiagramConfig()
        )

        let positioned = try layoutRequirementDiagram(diagram)
        XCTAssertGreaterThanOrEqual(positioned.edges.count, 1)
        for edge in positioned.edges {
            XCTAssertGreaterThanOrEqual(edge.path.count, 2)
        }
    }

    func testContainsEdgeSolid() throws {
        let diagram = RequirementDiagram(
            requirements: [
                RequirementNode(name: "A", type: .requirement, requirementId: "1", text: "t", risk: nil, verifyMethod: nil, cssStyles: [], classes: ["default"], sourceOrder: 0),
                RequirementNode(name: "B", type: .requirement, requirementId: "2", text: "t", risk: nil, verifyMethod: nil, cssStyles: [], classes: ["default"], sourceOrder: 1),
            ],
            elements: [],
            relationships: [
                RequirementRelationship(type: .contains, sourceName: "A", destinationName: "B", isReversed: false),
            ],
            classDefs: [],
            direction: .TB,
            config: RequirementDiagramConfig()
        )

        let positioned = try layoutRequirementDiagram(diagram)
        let containsEdge = positioned.edges[0]
        XCTAssertFalse(containsEdge.isDashed)
        XCTAssertEqual(containsEdge.startMarker, "requirement_contains")
        XCTAssertNil(containsEdge.endMarker)
    }

    func testNonContainsEdgeDashed() throws {
        let diagram = RequirementDiagram(
            requirements: [
                RequirementNode(name: "A", type: .requirement, requirementId: "1", text: "t", risk: nil, verifyMethod: nil, cssStyles: [], classes: ["default"], sourceOrder: 0),
                RequirementNode(name: "B", type: .requirement, requirementId: "2", text: "t", risk: nil, verifyMethod: nil, cssStyles: [], classes: ["default"], sourceOrder: 1),
            ],
            elements: [],
            relationships: [
                RequirementRelationship(type: .satisfies, sourceName: "A", destinationName: "B", isReversed: false),
            ],
            classDefs: [],
            direction: .TB,
            config: RequirementDiagramConfig()
        )

        let positioned = try layoutRequirementDiagram(diagram)
        let edge = positioned.edges[0]
        XCTAssertTrue(edge.isDashed)
        XCTAssertEqual(edge.endMarker, "requirement_arrow")
        XCTAssertNil(edge.startMarker)
    }

    func testEdgeLabelText() throws {
        let diagram = RequirementDiagram(
            requirements: [
                RequirementNode(name: "A", type: .requirement, requirementId: "1", text: "t", risk: nil, verifyMethod: nil, cssStyles: [], classes: ["default"], sourceOrder: 0),
                RequirementNode(name: "B", type: .requirement, requirementId: "2", text: "t", risk: nil, verifyMethod: nil, cssStyles: [], classes: ["default"], sourceOrder: 1),
            ],
            elements: [],
            relationships: [
                RequirementRelationship(type: .derives, sourceName: "A", destinationName: "B", isReversed: false),
            ],
            classDefs: [],
            direction: .TB,
            config: RequirementDiagramConfig()
        )

        let positioned = try layoutRequirementDiagram(diagram)
        let edge = positioned.edges[0]
        XCTAssertEqual(edge.labelText, "<<derives>>")
    }

    func testIsRequirementFlag() throws {
        let diagram = RequirementDiagram(
            requirements: [
                RequirementNode(name: "R1", type: .requirement, requirementId: "1", text: "t", risk: nil, verifyMethod: nil, cssStyles: [], classes: ["default"], sourceOrder: 0),
            ],
            elements: [
                ElementNode(name: "E1", type: "sim", docRef: "", cssStyles: [], classes: ["default"], sourceOrder: 1),
            ],
            relationships: [],
            classDefs: [],
            direction: .TB,
            config: RequirementDiagramConfig()
        )

        let positioned = try layoutRequirementDiagram(diagram)
        for node in positioned.nodes {
            if node.id == "R1" {
                XCTAssertTrue(node.isRequirement)
            } else if node.id == "E1" {
                XCTAssertFalse(node.isRequirement)
            }
        }
    }

    func testEmptyDiagram() throws {
        let diagram = RequirementDiagram(
            requirements: [], elements: [], relationships: [],
            classDefs: [], direction: .TB, config: RequirementDiagramConfig()
        )
        let positioned = try layoutRequirementDiagram(diagram)
        XCTAssertEqual(positioned.width, 0)
        XCTAssertEqual(positioned.height, 0)
        XCTAssertEqual(positioned.nodes.count, 0)
        XCTAssertEqual(positioned.edges.count, 0)
    }
}
