import Testing
@testable import DiagramKitPlantUML

@Suite("PlantUMLDeploymentProbeTests")
struct PlantUMLDeploymentProbeTests {

    @Test func acceptsNodeBlock() {
        let body = #"""
        node "Application Server" as appserver {
          artifact "app.war" as app
        }
        """#
        #expect(isPlantUMLDeploymentBody(body))
    }

    @Test func acceptsCloudBlock() {
        let body = #"""
        cloud "AWS" as aws {
          node "EC2" as ec2
        }
        """#
        #expect(isPlantUMLDeploymentBody(body))
    }

    @Test func acceptsBareDatabase() {
        let body = #"database "Postgres" as db"#
        #expect(isPlantUMLDeploymentBody(body))
    }

    @Test func rejectsComponentBody() {
        let body = #"""
        [Web] --> [API]
        interface HTTP
        """#
        #expect(!isPlantUMLDeploymentBody(body))
    }

    @Test func rejectsSequenceBody() {
        let body = #"""
        Alice -> Bob: Hello
        actor User
        """#
        #expect(!isPlantUMLDeploymentBody(body))
    }

    @Test func rejectsClassBody() {
        let body = #"""
        class Foo {
          +bar()
        }
        """#
        #expect(!isPlantUMLDeploymentBody(body))
    }

    @Test func rejectsBareActor() {
        let body = #"actor User"#
        #expect(!isPlantUMLDeploymentBody(body))
    }

    @Test func acceptsHybridWithBoundary() {
        let body = #"""
        boundary "Public Network" as net
        node "Edge" as edge
        """#
        #expect(isPlantUMLDeploymentBody(body))
    }

    @Test func importerRoutesDeploymentBodyThroughDeploymentMapper() throws {
        let source = #"""
        @startuml
        cloud "AWS" as aws {
          node "EC2" as ec2
        }
        database "Postgres" as db
        ec2 --> db : writes
        @enduml
        """#
        let result = try PlantUMLImporter().parse(source)
        guard case .architecture(let arch) = result.document.payload else {
            Issue.record("Expected architecture payload, got \(result.document.payload)"); return
        }
        #expect(arch.services.contains { $0.id == "ec2" && $0.kind == .node })
        #expect(arch.services.contains { $0.id == "db" && $0.kind == .database })
        #expect(arch.groups.contains { $0.id == "aws" })
    }

    @Test func importerStillRoutesComponentBodyThroughComponentMapper() throws {
        let source = #"""
        @startuml
        [Web] --> [API]
        interface HTTP
        [API] --> HTTP
        @enduml
        """#
        let result = try PlantUMLImporter().parse(source)
        guard case .architecture(let arch) = result.document.payload else {
            Issue.record("Expected architecture, got \(result.document.payload)"); return
        }
        let kinds = Set(arch.services.map(\.kind))
        #expect(kinds.isSubset(of: [.component, .interface]))
    }
}
