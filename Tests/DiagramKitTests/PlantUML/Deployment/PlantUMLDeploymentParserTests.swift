import Testing
import DiagramKitModel

@Suite("PlantUMLDeploymentParserTests")
struct PlantUMLDeploymentParserTests {

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
