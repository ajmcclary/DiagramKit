import Testing
import DiagramKitModel
@testable import DiagramKitPlantUML

@Suite("PlantUMLDeploymentMapperTests")
struct PlantUMLDeploymentMapperTests {

    @Test func flatShapesBecomeServices() throws {
        let ast = PlantUMLDeploymentAST(
            roots: [
                .shape(.init(id: "a", label: "A", kind: .node)),
                .shape(.init(id: "b", label: "B", kind: .database))
            ]
        )
        let (diagram, diagnostics) = PlantUMLDeploymentMapper().map(ast)
        #expect(diagnostics.isEmpty)
        #expect(diagram.services.map(\.id).sorted() == ["a", "b"])
        let a = diagram.services.first { $0.id == "a" }
        #expect(a?.kind == .node)
        #expect(a?.title == "A")
        let b = diagram.services.first { $0.id == "b" }
        #expect(b?.kind == .database)
    }

    @Test func groupBecomesArchitectureGroupWithChildrenParented() throws {
        let ast = PlantUMLDeploymentAST(
            roots: [
                .group(.init(
                    id: "aws", label: "AWS", kind: .cloud,
                    children: [
                        .shape(.init(id: "ec2", label: "EC2", kind: .node))
                    ]
                ))
            ]
        )
        let (diagram, _) = PlantUMLDeploymentMapper().map(ast)
        #expect(diagram.groups.map(\.id) == ["aws"])
        #expect(diagram.services.map(\.id) == ["ec2"])
        let ec2 = diagram.services.first { $0.id == "ec2" }
        #expect(ec2?.parentGroupId == "aws")
    }

    @Test func threeLevelNestingPreservesParentage() throws {
        let ast = PlantUMLDeploymentAST(
            roots: [
                .group(.init(id: "aws", label: nil, kind: .cloud, children: [
                    .group(.init(id: "ec2", label: nil, kind: .node, children: [
                        .shape(.init(id: "worker", label: nil, kind: .artifact))
                    ]))
                ]))
            ]
        )
        let (diagram, _) = PlantUMLDeploymentMapper().map(ast)
        let aws = diagram.groups.first { $0.id == "aws" }
        let ec2 = diagram.groups.first { $0.id == "ec2" }
        let worker = diagram.services.first { $0.id == "worker" }
        #expect(aws?.parentGroupId == nil)
        #expect(ec2?.parentGroupId == "aws")
        #expect(worker?.parentGroupId == "ec2")
    }

    @Test func edgesBecomeArchitectureEdges() throws {
        let ast = PlantUMLDeploymentAST(
            roots: [
                .shape(.init(id: "a", label: nil, kind: .node)),
                .shape(.init(id: "b", label: nil, kind: .node))
            ],
            edges: [.init(lhsId: "a", rhsId: "b", direction: .forward, style: .solid, label: "writes")]
        )
        let (diagram, _) = PlantUMLDeploymentMapper().map(ast)
        #expect(diagram.edges.count == 1)
        let edge = diagram.edges[0]
        #expect(edge.lhsId == "a")
        #expect(edge.rhsId == "b")
        #expect(edge.label == "writes")
        #expect(edge.lhsDirection == .R)
        #expect(edge.rhsDirection == .L)
    }

    @Test func titlePropagates() throws {
        let ast = PlantUMLDeploymentAST(title: "Deployment Diagram", roots: [])
        let (diagram, _) = PlantUMLDeploymentMapper().map(ast)
        #expect(diagram.diagramTitle == "Deployment Diagram")
    }
}
