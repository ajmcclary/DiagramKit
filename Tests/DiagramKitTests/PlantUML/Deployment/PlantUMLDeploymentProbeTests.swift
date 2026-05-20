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
}
