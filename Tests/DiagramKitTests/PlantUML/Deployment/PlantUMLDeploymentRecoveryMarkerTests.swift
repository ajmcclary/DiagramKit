import Testing
import Foundation
@testable import DiagramKitPlantUML

@Suite("PlantUMLDeploymentRecoveryMarkerTests")
struct PlantUMLDeploymentRecoveryMarkerTests {

    @Test func serviceStereotypeRoundTrip() {
        let emitted = PlantUMLRecoveryMarker.emitDeploymentServiceStereotype(
            serviceId: "worker_1",
            stereotype: "router"
        )
        #expect(emitted == "' diagramkit:deployment-service-stereotype=worker_1,router")
        let parsed = PlantUMLRecoveryMarker.scanner.scan(source: emitted).markers.first?.kind
        #expect(parsed == .deploymentServiceStereotype(serviceId: "worker_1", stereotype: "router"))
    }

    @Test func serviceColorRoundTrip() {
        let emitted = PlantUMLRecoveryMarker.emitDeploymentServiceColor(serviceId: "db_3", color: "#FF6600")
        #expect(emitted == "' diagramkit:deployment-service-color=db_3,#FF6600")
        let parsed = PlantUMLRecoveryMarker.scanner.scan(source: emitted).markers.first?.kind
        #expect(parsed == .deploymentServiceColor(serviceId: "db_3", color: "#FF6600"))
    }

    @Test func groupKindRoundTrip() {
        let emitted = PlantUMLRecoveryMarker.emitDeploymentGroupKind(groupId: "cloud_2", kindRawValue: "cloud")
        #expect(emitted == "' diagramkit:deployment-group-kind=cloud_2,cloud")
        let parsed = PlantUMLRecoveryMarker.scanner.scan(source: emitted).markers.first?.kind
        #expect(parsed == .deploymentGroupKind(groupId: "cloud_2", kindRawValue: "cloud"))
    }

    @Test func edgeStyleRoundTrip() {
        let emitted = PlantUMLRecoveryMarker.emitDeploymentEdgeStyle(edgeIndex: 4, style: "dashed")
        #expect(emitted == "' diagramkit:deployment-edge-style=4,dashed")
        let parsed = PlantUMLRecoveryMarker.scanner.scan(source: emitted).markers.first?.kind
        #expect(parsed == .deploymentEdgeStyle(edgeIndex: 4, style: "dashed"))
    }

    @Test func noteRoundTripWithBase64Body() {
        let body = "This node handles all incoming traffic."
        let emitted = PlantUMLRecoveryMarker.emitDeploymentNote(
            serviceId: "worker_1",
            position: "right",
            body: body
        )
        #expect(emitted.hasPrefix("' diagramkit:deployment-note=worker_1,right,b64:"))
        let parsed = PlantUMLRecoveryMarker.scanner.scan(source: emitted).markers.first?.kind
        if case let .deploymentNote(serviceId, position, base64) = parsed {
            #expect(serviceId == "worker_1")
            #expect(position == "right")
            let decoded = Data(base64Encoded: base64).flatMap { String(data: $0, encoding: .utf8) }
            #expect(decoded == body)
        } else {
            Issue.record("Expected .deploymentNote, got \(String(describing: parsed))")
        }
    }

    @Test func legendRoundTripWithBase64Body() {
        let body = "Requires VPN access"
        let emitted = PlantUMLRecoveryMarker.emitDeploymentLegend(body: body)
        #expect(emitted.hasPrefix("' diagramkit:deployment-legend=b64:"))
        let parsed = PlantUMLRecoveryMarker.scanner.scan(source: emitted).markers.first?.kind
        if case let .deploymentLegend(base64) = parsed {
            let decoded = Data(base64Encoded: base64).flatMap { String(data: $0, encoding: .utf8) }
            #expect(decoded == body)
        } else {
            Issue.record("Expected .deploymentLegend, got \(String(describing: parsed))")
        }
    }
}
