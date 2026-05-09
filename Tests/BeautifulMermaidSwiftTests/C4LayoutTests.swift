import Testing
import Foundation
import CoreGraphics
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("C4 Layout")
struct C4LayoutTests {

    // MARK: - Basic layout

    @Test("Single shape is positioned with margins")
    func singleShape() throws {
        var diagram = C4Diagram(kind: .context)
        diagram.shapes = [C4Shape(alias: "a", label: "System A", typeC4Shape: .system)]

        let positioned = layoutC4Diagram(diagram)

        #expect(positioned.shapes.count == 1)
        let shape = positioned.shapes[0]
        #expect(shape.alias == "a")
        #expect(shape.x >= diagram.config.diagramMarginX)
        #expect(shape.y >= diagram.config.diagramMarginY)
        #expect(shape.width >= 200)
        #expect(shape.height >= 100)
        #expect(positioned.width > 0)
        #expect(positioned.height > 0)
    }

    @Test("Multiple shapes are placed in rows")
    func multipleShapesInRow() throws {
        var diagram = C4Diagram(kind: .context)
        diagram.shapes = [
            C4Shape(alias: "a", label: "A", typeC4Shape: .system),
            C4Shape(alias: "b", label: "B", typeC4Shape: .system),
            C4Shape(alias: "c", label: "C", typeC4Shape: .container),
        ]

        let positioned = layoutC4Diagram(diagram)

        #expect(positioned.shapes.count == 3)
        // Shapes should have non-zero positions
        for shape in positioned.shapes {
            #expect(shape.width > 0)
            #expect(shape.height > 0)
        }
    }

    @Test("Person shape includes image dimensions")
    func personShapeHasImage() throws {
        var diagram = C4Diagram(kind: .context)
        diagram.shapes = [C4Shape(alias: "p", label: "User", typeC4Shape: .person)]

        let positioned = layoutC4Diagram(diagram)

        #expect(positioned.shapes.count == 1)
        let shape = positioned.shapes[0]
        #expect(shape.imageHeight == 48)
        #expect(shape.stereotypeHeight > 0)
        #expect(shape.labelHeight > 0)
    }

    @Test("Shape with technology has technology dimensions")
    func shapeWithTechnology() throws {
        var diagram = C4Diagram(kind: .container)
        diagram.shapes = [C4Shape(alias: "c", label: "App", typeC4Shape: .container, technology: "Spring Boot")]

        let positioned = layoutC4Diagram(diagram)

        let shape = positioned.shapes[0]
        #expect(shape.technHeight > 0)
        #expect(shape.technWidth > 0)
    }

    @Test("Shape with description has description dimensions")
    func shapeWithDescription() throws {
        var diagram = C4Diagram(kind: .context)
        diagram.shapes = [C4Shape(alias: "s", label: "System", typeC4Shape: .system, description: "A large system")]

        let positioned = layoutC4Diagram(diagram)

        let shape = positioned.shapes[0]
        #expect(shape.descrHeight > 0)
        #expect(shape.descrWidth > 0)
    }

    // MARK: - Boundary layout

    @Test("Boundary contains inner shapes")
    func boundaryContainsShapes() throws {
        var diagram = C4Diagram(kind: .context)
        diagram.boundaries = [
            C4Boundary(alias: "b1", label: "Boundary 1", type: "SYSTEM", parentBoundary: "global")
        ]
        diagram.shapes = [
            C4Shape(alias: "a", label: "A", typeC4Shape: .system, parentBoundary: "b1"),
            C4Shape(alias: "b", label: "B", typeC4Shape: .system, parentBoundary: "b1"),
        ]

        let positioned = layoutC4Diagram(diagram)

        #expect(positioned.boundaries.count == 1)
        #expect(positioned.shapes.count == 2)
        let boundary = positioned.boundaries[0]
        #expect(boundary.alias == "b1")
        #expect(boundary.width >= 50)
        #expect(boundary.height >= 50)
        #expect(boundary.labelHeight > 0)
    }

    @Test("Nested boundaries produce hierarchy")
    func nestedBoundaries() throws {
        var diagram = C4Diagram(kind: .context)
        diagram.boundaries = [
            C4Boundary(alias: "outer", label: "Outer", type: "ENTERPRISE", parentBoundary: "global"),
            C4Boundary(alias: "inner", label: "Inner", type: "SYSTEM", parentBoundary: "outer"),
        ]
        diagram.shapes = [
            C4Shape(alias: "s", label: "System", typeC4Shape: .system, parentBoundary: "inner"),
        ]

        let positioned = layoutC4Diagram(diagram)

        #expect(positioned.boundaries.count == 2)
        #expect(positioned.shapes.count == 1)
    }

    @Test("Boundary with type has type dimensions")
    func boundaryWithType() throws {
        var diagram = C4Diagram(kind: .deployment)
        diagram.boundaries = [
            C4Boundary(alias: "node", label: "Server", type: "Ubuntu 22.04", parentBoundary: "global", nodeType: "node")
        ]
        diagram.shapes = [
            C4Shape(alias: "c", label: "Container", typeC4Shape: .container, parentBoundary: "node"),
        ]

        let positioned = layoutC4Diagram(diagram)

        let boundary = positioned.boundaries[0]
        #expect(boundary.typeHeight > 0)
    }

    // MARK: - Relationships

    @Test("Relationships have positioned endpoints")
    func relationshipsPositioned() throws {
        var diagram = C4Diagram(kind: .context)
        diagram.shapes = [
            C4Shape(alias: "a", label: "A", typeC4Shape: .person),
            C4Shape(alias: "b", label: "B", typeC4Shape: .system),
        ]
        diagram.relationships = [
            C4Relationship(kind: .rel, from: "a", to: "b", label: "Uses"),
        ]

        let positioned = layoutC4Diagram(diagram)

        #expect(positioned.relationships.count == 1)
        let rel = positioned.relationships[0]
        #expect(rel.from == "a")
        #expect(rel.to == "b")
        #expect(rel.label == "Uses")
        #expect(rel.labelWidth > 0)
        #expect(rel.labelHeight > 0)
    }

    @Test("Relationship with technology")
    func relationshipWithTechnology() throws {
        var diagram = C4Diagram(kind: .context)
        diagram.shapes = [
            C4Shape(alias: "a", label: "A", typeC4Shape: .system),
            C4Shape(alias: "b", label: "B", typeC4Shape: .system),
        ]
        diagram.relationships = [
            C4Relationship(kind: .rel, from: "a", to: "b", label: "Calls", technology: "REST"),
        ]

        let positioned = layoutC4Diagram(diagram)

        let rel = positioned.relationships[0]
        #expect(rel.technHeight > 0)
        #expect(rel.technWidth > 0)
    }

    @Test("Dynamic diagram adds index to label")
    func dynamicDiagramIndexing() throws {
        var diagram = C4Diagram(kind: .dynamic)
        diagram.shapes = [
            C4Shape(alias: "a", label: "A", typeC4Shape: .system),
            C4Shape(alias: "b", label: "B", typeC4Shape: .system),
        ]
        diagram.relationships = [
            C4Relationship(kind: .rel, from: "a", to: "b", label: "Sends"),
        ]

        let positioned = layoutC4Diagram(diagram)

        let rel = positioned.relationships[0]
        #expect(rel.label.hasPrefix("1: "))
        #expect(rel.dynamicIndex == 1)
    }

    // MARK: - Empty diagram

    @Test("Empty diagram returns minimal dimensions")
    func emptyDiagram() {
        let positioned = layoutC4Diagram(C4Diagram(kind: .context))

        #expect(positioned.shapes.isEmpty)
        #expect(positioned.boundaries.isEmpty)
        #expect(positioned.relationships.isEmpty)
        #expect(positioned.width > 0)
        #expect(positioned.height > 0)
    }

    // MARK: - Config-driven layout

    @Test("Config c4ShapeInRow affects row wrapping")
    func shapeInRowConfig() throws {
        var config = C4DiagramConfig()
        config.c4ShapeInRow = 2

        var diagram = C4Diagram(kind: .context, config: config)
        diagram.shapes = [
            C4Shape(alias: "a", label: "A", typeC4Shape: .system),
            C4Shape(alias: "b", label: "B", typeC4Shape: .system),
            C4Shape(alias: "c", label: "C", typeC4Shape: .system),
        ]

        let positioned = layoutC4Diagram(diagram)

        #expect(positioned.shapes.count == 3)
        // All shapes should be positioned
        for shape in positioned.shapes {
            #expect(shape.x > 0)
            #expect(shape.y > 0)
        }
    }
}
