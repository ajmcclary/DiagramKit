import Testing
import DiagramKitModel
@testable import DiagramKitPlantUML

@Suite("PlantUMLDeploymentParserTests")
struct PlantUMLDeploymentParserTests {

    @Test func astTypesConstructible() {
        let shape = PlantUMLDeploymentAST.Shape(
            id: "worker", label: "Worker", kind: .node,
            stereotype: "router", color: "#FF6600"
        )
        let group = PlantUMLDeploymentAST.Group(
            id: "cloud_1", label: "AWS", kind: .cloud,
            stereotype: nil, color: nil, children: [.shape(shape)]
        )
        let edge = PlantUMLDeploymentAST.Edge(
            lhsId: "worker", rhsId: "db",
            direction: .forward, style: .solid,
            label: "writes", stereotype: nil
        )
        let ast = PlantUMLDeploymentAST(
            title: "Deployment", roots: [.group(group)],
            edges: [edge], notes: [], legend: nil
        )
        #expect(ast.title == "Deployment")
        #expect(ast.roots.count == 1)
        #expect(ast.edges.count == 1)
    }

    @Test func architectureServiceKindHasDeploymentCases() {
        #expect(ArchitectureServiceKind.node.rawValue == "node")
        #expect(ArchitectureServiceKind.artifact.rawValue == "artifact")
        #expect(ArchitectureServiceKind.database.rawValue == "database")
        #expect(ArchitectureServiceKind.cloud.rawValue == "cloud")
        #expect(ArchitectureServiceKind.frame.rawValue == "frame")
        #expect(ArchitectureServiceKind.folder.rawValue == "folder")
        #expect(ArchitectureServiceKind.package.rawValue == "package")
        #expect(ArchitectureServiceKind.card.rawValue == "card")
        #expect(ArchitectureServiceKind.queue.rawValue == "queue")
        #expect(ArchitectureServiceKind.stack.rawValue == "stack")
        #expect(ArchitectureServiceKind.storage.rawValue == "storage")
        #expect(ArchitectureServiceKind.agent.rawValue == "agent")
        #expect(ArchitectureServiceKind.actor.rawValue == "actor")
        #expect(ArchitectureServiceKind.boundary.rawValue == "boundary")

        let allDeploymentCases: Set<ArchitectureServiceKind> = [
            .node, .artifact, .database, .cloud, .frame, .folder,
            .package, .card, .queue, .stack, .storage, .agent,
            .actor, .boundary
        ]
        #expect(allDeploymentCases.count == 14)
        #expect(ArchitectureServiceKind.allCases.count == 17) // 3 existing + 14
    }
}
