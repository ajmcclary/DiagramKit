import Foundation
import Testing
import DiagramKitImport
import DiagramKitModel
@testable import DiagramKitGraphviz

@Suite("DOTC4Mapper")
struct DOTC4MapperTests {

    @Test func parsesFamilyMarkerAndDiagramKind() throws {
        let source = """
        digraph G {
            # diagramkit:family=c4
            # diagramkit:c4-diagram-kind=C4Container

            u [shape=oval, label="User"];
            # diagramkit:c4-shape-kind=u,person
        }
        """
        let result = try GraphvizImporter().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.kind == .container)
        #expect(diagram.shapes.first?.alias == "u")
        #expect(diagram.shapes.first?.typeC4Shape == .person)
    }

    @Test func recoversShapeKindMarker() throws {
        let source = """
        digraph G {
            # diagramkit:family=c4
            # diagramkit:c4-diagram-kind=C4Container

            db [shape=cylinder, label="Cache"];
            # diagramkit:c4-shape-kind=db,container_db
        }
        """
        let result = try GraphvizImporter().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.shapes.first?.typeC4Shape == .container_db)
    }

    @Test func recoversExternalMarker() throws {
        let source = """
        digraph G {
            # diagramkit:family=c4
            # diagramkit:c4-diagram-kind=C4Context

            u [shape=oval, label="Customer"];
            # diagramkit:c4-shape-kind=u,person
            # diagramkit:c4-external=u
        }
        """
        let result = try GraphvizImporter().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.shapes.first?.typeC4Shape == .external_person)
    }

    @Test func recoversBoundaryClusterAndKindMarker() throws {
        let source = """
        digraph G {
            # diagramkit:family=c4
            # diagramkit:c4-diagram-kind=C4Container

            subgraph cluster_ent {
                label = "Enterprise";
                svc [shape=box, label="Service"];
                # diagramkit:c4-shape-kind=svc,container
            }
            # diagramkit:c4-boundary-kind=ent,enterprise
        }
        """
        let result = try GraphvizImporter().parse(source)
        let diagram = try requireC4(result)
        let ent = diagram.boundaries.first { $0.alias == "ent" }
        #expect(ent?.label == "Enterprise")
        #expect(ent?.type == "enterprise")
        #expect(diagram.shapes.first?.parentBoundary == "ent")
        #expect(diagram.shapes.first?.typeC4Shape == .container)
    }

    @Test func recoversRelKindMarker() throws {
        let source = """
        digraph G {
            # diagramkit:family=c4
            # diagramkit:c4-diagram-kind=C4Context

            a [shape=box, label="A"];
            b [shape=box, label="B"];
            a -> b [label="uses"];
            # diagramkit:c4-rel-kind=0,rel_u
        }
        """
        let result = try GraphvizImporter().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.relationships.first?.kind == .rel_u)
    }

    @Test func recoversPackedColors() throws {
        let source = """
        digraph G {
            # diagramkit:family=c4
            # diagramkit:c4-diagram-kind=C4Context

            svc [shape=box, label="Service"];
            # diagramkit:c4-color=svc,bg=#fff;font=#000;border=#888
        }
        """
        let result = try GraphvizImporter().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.shapes.first?.bgColor == "#fff")
        #expect(diagram.shapes.first?.fontColor == "#000")
        #expect(diagram.shapes.first?.borderColor == "#888")
    }

    @Test func defaultsDiagramKindToContextWithDiagnostic() throws {
        let source = """
        digraph G {
            # diagramkit:family=c4
            u [shape=oval, label="User"];
            # diagramkit:c4-shape-kind=u,person
        }
        """
        let result = try GraphvizImporter().parse(source)
        let diagram = try requireC4(result)
        #expect(diagram.kind == .context)
        #expect(result.diagnostics.contains { $0.message.contains("c4-diagram-kind") })
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
