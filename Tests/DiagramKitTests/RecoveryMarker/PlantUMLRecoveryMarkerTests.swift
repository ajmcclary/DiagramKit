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
        let source = "' diagramkit:sequence-participant-link=alice,https://example.com/alice"
        let result = PlantUMLRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .sequenceParticipantLink(participantId: "alice", url: "https://example.com/alice"))
    }

    @Test("parses sequence-participant-property marker")
    func parsesParticipantProperty() {
        let source = "' diagramkit:sequence-participant-property=alice,role,manager"
        let result = PlantUMLRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .sequenceParticipantProperty(participantId: "alice", key: "role", value: "manager"))
    }

    @Test("parses sequence-participant-details with base64")
    func parsesParticipantDetailsBase64() {
        let source = "' diagramkit:sequence-participant-details=alice,b64:VGhpcyBpcyBhIGRldGFpbCBibG9jay4="
        let result = PlantUMLRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .sequenceParticipantDetails(
            participantId: "alice",
            base64: "VGhpcyBpcyBhIGRldGFpbCBibG9jay4="
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

    @Test("emits valid sequence-participant-details with base64")
    func emitsSequenceParticipantDetails() {
        let line = PlantUMLRecoveryMarker.emitSequenceParticipantDetails(participantId: "alice", details: "This is a detail block.")
        #expect(line.contains("' diagramkit:sequence-participant-details=alice,b64:"))
        // Round-trip the base64
        let result = PlantUMLRecoveryMarker.scanner.scan(source: line)
        guard case .sequenceParticipantDetails(_, let b64) = result.markers.first?.kind else {
            Issue.record("expected details marker")
            return
        }
        guard let decoded = Data(base64Encoded: b64),
              let text = String(data: decoded, encoding: .utf8) else {
            Issue.record("base64 decode failed")
            return
        }
        #expect(text == "This is a detail block.")
    }
}
