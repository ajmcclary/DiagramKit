import Testing
import Foundation
@testable import DiagramKitPlantUML

@Suite("PlantUML recovery marker")
struct PlantUMLRecoveryMarkerTests {

    @Test("parses activity-partition marker")
    func parsesActivityPartition() {
        let source = "' diagramkit:activity-partition=order_create,OrderProcessing"
        let result = PlantUMLRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .activityPartition(originalId: "order_create", partition: "OrderProcessing"))
    }

    @Test("parses activity-original-id marker")
    func parsesActivityOriginalId() {
        let source = "' diagramkit:activity-original-id=s0,placeOrder"
        let result = PlantUMLRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .activityOriginalId(syntheticId: "s0", originalId: "placeOrder"))
    }

    @Test("parses sequence-participant-link marker")
    func parsesParticipantLink() {
        let source = "' diagramkit:sequence-participant-link=alice,Profile,https://example.com/alice"
        let result = PlantUMLRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .sequenceParticipantLink(
            participantId: "alice",
            label: "Profile",
            url: "https://example.com/alice"
        ))
    }

    @Test("parses sequence-participant-properties marker (base64 json)")
    func parsesParticipantProperties() {
        let source = "' diagramkit:sequence-participant-properties=alice,b64:eyJhIjoxfQ=="
        let result = PlantUMLRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .sequenceParticipantProperties(participantId: "alice", base64Json: "eyJhIjoxfQ=="))
    }

    @Test("parses sequence-participant-details marker (elementId reference)")
    func parsesParticipantDetails() {
        let source = "' diagramkit:sequence-participant-details=alice,elem42"
        let result = PlantUMLRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .sequenceParticipantDetails(
            participantId: "alice",
            elementId: "elem42"
        ))
    }

    @Test("does not match # comment prefix (PlantUML uses ')")
    func ignoresHashComments() {
        let source = "# diagramkit:activity-partition=foo,bar"
        let result = PlantUMLRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.isEmpty)
    }

    @Test("emits valid activity-partition line")
    func emitsActivityPartition() {
        let line = PlantUMLRecoveryMarker.emitActivityPartition(originalId: "order_create", partition: "OrderProcessing")
        #expect(line == "' diagramkit:activity-partition=order_create,OrderProcessing")
    }

    @Test("emits valid sequence-participant-properties with base64-encoded JSON")
    func emitsSequenceParticipantProperties() {
        let line = PlantUMLRecoveryMarker.emitSequenceParticipantProperties(
            participantId: "alice",
            json: "{\"role\":\"manager\"}"
        )
        #expect(line.contains("' diagramkit:sequence-participant-properties=alice,b64:"))
        let result = PlantUMLRecoveryMarker.scanner.scan(source: line)
        guard case .sequenceParticipantProperties(_, let b64) = result.markers.first?.kind else {
            Issue.record("expected properties marker")
            return
        }
        guard let decoded = Data(base64Encoded: b64),
              let text = String(data: decoded, encoding: .utf8) else {
            Issue.record("base64 decode failed")
            return
        }
        #expect(text == "{\"role\":\"manager\"}")
    }
}
