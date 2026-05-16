import Testing
import Foundation
@testable import DiagramKitModel

private func erLines(_ source: String) -> [String] {
    source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
}

private func laidOut(_ source: String) throws -> PositionedErDiagram {
    let (diagram, _) = try parseErDiagram(erLines(source))
    return try layoutErDiagramSync(diagram)
}

private func rectsOverlap(_ a: PositionedErEntity, _ b: PositionedErEntity) -> Bool {
    let ax2 = a.x + a.width
    let ay2 = a.y + a.height
    let bx2 = b.x + b.width
    let by2 = b.y + b.height
    return !(ax2 <= b.x || bx2 <= a.x || ay2 <= b.y || by2 <= a.y)
}

@Suite("ER Layout", .serialized)
@MainActor
struct ERLayoutTests {

    @Test func emptyDiagramReturnsZeroBoundsWithoutThrow() throws {
        let positioned = try laidOut("erDiagram")
        #expect(positioned.entities.isEmpty)
        #expect(positioned.relationships.isEmpty)
        #expect(positioned.width == 0)
        #expect(positioned.height == 0)
    }

    @Test func singleEntityHasPositiveBounds() throws {
        let positioned = try laidOut("""
        erDiagram
            CUSTOMER {
                int id PK
                string name
            }
        """)
        #expect(positioned.entities.count == 1)
        let e = positioned.entities[0]
        #expect(e.width > 0)
        #expect(e.height > 0)
        #expect(positioned.width >= e.width)
        #expect(positioned.height >= e.height)
    }

    @Test func entityWithMoreAttributesIsTaller() throws {
        let shortDiagram = try laidOut("""
        erDiagram
            CUSTOMER {
                int id
            }
        """)
        let tallDiagram = try laidOut("""
        erDiagram
            CUSTOMER {
                int id
                string name
                string email
                float balance
                bool active
            }
        """)
        let short = shortDiagram.entities.first(where: { $0.id == "CUSTOMER" })
        let tall = tallDiagram.entities.first(where: { $0.id == "CUSTOMER" })
        #expect(short != nil)
        #expect(tall != nil)
        #expect((tall?.height ?? 0) > (short?.height ?? 0))
    }

    @Test func multipleEntitiesDoNotOverlap() throws {
        let positioned = try laidOut("""
        erDiagram
            CUSTOMER ||--o{ ORDER : places
            ORDER ||--|{ LINE_ITEM : contains
        """)
        let entities = positioned.entities
        #expect(entities.count == 3)
        for i in 0..<entities.count {
            for j in (i + 1)..<entities.count {
                let aKey = entities[i].id
                let bKey = entities[j].id
                #expect(!rectsOverlap(entities[i], entities[j]),
                        "entities \(aKey) and \(bKey) overlap")
            }
        }
    }

    @Test func relationshipEndpointsTouchEntityBounds() throws {
        let positioned = try laidOut("""
        erDiagram
            CUSTOMER ||--o{ ORDER : places
        """)
        #expect(positioned.relationships.count == 1)
        let rel = positioned.relationships[0]
        #expect(rel.points.count >= 2)
        // The first and last point should land at one of the two entity bounding rects (within 1px tolerance).
        let first = rel.points.first!
        let last = rel.points.last!
        let touches = positioned.entities.contains { e in
            let x1 = e.x, y1 = e.y, x2 = e.x + e.width, y2 = e.y + e.height
            let onEdge: (Double, Double) -> Bool = { px, py in
                let tol = 1.0
                let onVerticalEdge = (abs(px - x1) < tol || abs(px - x2) < tol) && py >= y1 - tol && py <= y2 + tol
                let onHorizontalEdge = (abs(py - y1) < tol || abs(py - y2) < tol) && px >= x1 - tol && px <= x2 + tol
                return onVerticalEdge || onHorizontalEdge
            }
            return onEdge(first.x, first.y) || onEdge(last.x, last.y)
        }
        #expect(touches)
    }

    @Test func selfRelationshipLaysOutBothEndsOnSameEntity() throws {
        let positioned = try laidOut("""
        erDiagram
            EMPLOYEE ||--o{ EMPLOYEE : manages
        """)
        #expect(positioned.entities.count == 1)
        #expect(positioned.relationships.count == 1)
        let rel = positioned.relationships[0]
        #expect(rel.entity1 == "EMPLOYEE")
        #expect(rel.entity2 == "EMPLOYEE")
        #expect(rel.points.count >= 2)
    }

    @Test func manyEntitiesProduceNonDegenerateLayout() throws {
        let positioned = try laidOut("""
        erDiagram
            A ||--|| B : ab
            B ||--|| C : bc
            C ||--|| D : cd
            D ||--|| E : de
            E ||--|| F : ef
            F ||--|| G : fg
            G ||--|| H : gh
            H ||--|| I : hi
            I ||--|| J : ij
            J ||--|| A : ja
        """)
        #expect(positioned.entities.count == 10)
        // Each entity has positive size.
        for entity in positioned.entities {
            #expect(entity.width > 0)
            #expect(entity.height > 0)
        }
        // Total bounds large enough to contain all entities.
        let maxX = positioned.entities.map { $0.x + $0.width }.max() ?? 0
        let maxY = positioned.entities.map { $0.y + $0.height }.max() ?? 0
        #expect(positioned.width >= maxX)
        #expect(positioned.height >= maxY)
    }

    @Test func layoutIsDeterministic() throws {
        let source = """
        erDiagram
            CUSTOMER ||--o{ ORDER : places
            ORDER ||--|{ LINE_ITEM : contains
        """
        let a = try laidOut(source)
        let b = try laidOut(source)
        #expect(a.width == b.width)
        #expect(a.height == b.height)
        let aIds = a.entities.map(\.id)
        let bIds = b.entities.map(\.id)
        #expect(aIds == bIds)
        for (e1, e2) in zip(a.entities, b.entities) {
            #expect(e1.x == e2.x)
            #expect(e1.y == e2.y)
        }
    }

    @Test func accessibilityMetadataIsPreservedThroughLayout() throws {
        let (diagram, _) = try parseErDiagram(erLines("""
        erDiagram
            accTitle: Customer schema
            accDescr: Persistent storage for customers
            title Customer Database
            CUSTOMER
        """))
        let positioned = try layoutErDiagramSync(diagram)
        #expect(positioned.accTitle == "Customer schema")
        #expect(positioned.accDescr == "Persistent storage for customers")
    }

    @Test func relationshipCardinalityStringsCarryThroughToLayout() throws {
        let positioned = try laidOut("""
        erDiagram
            CUSTOMER ||--o{ ORDER : places
        """)
        let rel = positioned.relationships[0]
        // Convention: cardinality1 maps to relSpec.cardB (the `||` side),
        // cardinality2 maps to relSpec.cardA (the `o{` side).
        #expect(rel.cardinality1 == "ONLY_ONE")
        #expect(rel.cardinality2 == "ZERO_OR_MORE")
        #expect(rel.identifying == true)
    }
}
