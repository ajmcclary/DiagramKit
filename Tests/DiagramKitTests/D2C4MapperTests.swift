import Foundation
import Testing
import DiagramKitImport
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2C4Mapper")
struct D2C4MapperTests {

    @Test func parsesFamilyMarkerAndDiagramKind() throws {
        let source = """
        # diagramkit:family=c4
        # diagramkit:c4-diagram-kind=C4Container

        u: "User" {
            shape: person
        }
        """
        let result = try D2Importer().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.kind == .container)
        #expect(diagram.shapes.first?.alias == "u")
        #expect(diagram.shapes.first?.typeC4Shape == .person)
    }

    @Test func recoversShapeKindMarker() throws {
        let source = """
        # diagramkit:family=c4
        # diagramkit:c4-diagram-kind=C4Container

        db: "Cache" {
            shape: cylinder
        }
        # diagramkit:c4-shape-kind=db,container_db
        """
        let result = try D2Importer().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.shapes.first?.typeC4Shape == .container_db)
    }

    @Test func recoversExternalMarker() throws {
        let source = """
        # diagramkit:family=c4
        # diagramkit:c4-diagram-kind=C4Context

        u: "Customer" {
            shape: person
        }
        # diagramkit:c4-external=u
        """
        let result = try D2Importer().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.shapes.first?.typeC4Shape == .external_person)
    }

    @Test func recoversBoundaryNestingAndKindMarker() throws {
        let source = """
        # diagramkit:family=c4
        # diagramkit:c4-diagram-kind=C4Container

        ent: "Enterprise" {
            svc: "Service" {
                shape: rectangle
            }
            # diagramkit:c4-shape-kind=svc,container
        }
        # diagramkit:c4-boundary-kind=ent,enterprise
        """
        let result = try D2Importer().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.boundaries.first?.type == "enterprise")
        #expect(diagram.shapes.first?.parentBoundary == "ent")
        #expect(diagram.shapes.first?.typeC4Shape == .container)
    }

    @Test func recoversRelKindMarker() throws {
        let source = """
        # diagramkit:family=c4
        # diagramkit:c4-diagram-kind=C4Context

        a: "A" {
            shape: rectangle
        }
        b: "B" {
            shape: rectangle
        }
        a -> b: "uses"
        # diagramkit:c4-rel-kind=0,rel_u
        """
        let result = try D2Importer().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.relationships.first?.kind == .rel_u)
    }

    @Test func recoversTechnologyAndDescription() throws {
        let source = """
        # diagramkit:family=c4
        # diagramkit:c4-diagram-kind=C4Container

        svc: "Service" {
            shape: rectangle
        }
        # diagramkit:c4-shape-kind=svc,container
        # diagramkit:c4-technology=svc,Swift 6
        # diagramkit:c4-description=svc,Auth API
        """
        let result = try D2Importer().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.shapes.first?.technology == "Swift 6")
        #expect(diagram.shapes.first?.description == "Auth API")
    }

    @Test func recoversPackedColors() throws {
        let source = """
        # diagramkit:family=c4
        # diagramkit:c4-diagram-kind=C4Context

        svc: "Service" {
            shape: rectangle
        }
        # diagramkit:c4-color=svc,bg=#fff;font=#000;border=#888
        """
        let result = try D2Importer().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.shapes.first?.bgColor == "#fff")
        #expect(diagram.shapes.first?.fontColor == "#000")
        #expect(diagram.shapes.first?.borderColor == "#888")
    }

    @Test func defaultsDiagramKindToContextWithInformational() throws {
        let source = """
        # diagramkit:family=c4

        u: "User" {
            shape: person
        }
        """
        let result = try D2Importer().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.kind == .context)
        #expect(result.diagnostics.contains { $0.message.contains("c4-diagram-kind") })
    }

    @Test func recoversTagMarker() throws {
        let source = """
        # diagramkit:family=c4
        # diagramkit:c4-diagram-kind=C4Context

        svc: "Service" {
            shape: rectangle
        }
        # diagramkit:c4-tag=svc,internal,v2
        """
        let result = try D2Importer().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.shapes.first?.tags == "internal,v2")
    }

    private func requireC4(_ result: DiagramImportResult) throws -> C4Diagram {
        guard case .c4(let diagram) = result.document.typedPayload else {
            Issue.record("expected c4 payload, got \(result.document.typedPayload)")
            throw TestFailure()
        }
        return diagram
    }

    private struct TestFailure: Error {}
}
