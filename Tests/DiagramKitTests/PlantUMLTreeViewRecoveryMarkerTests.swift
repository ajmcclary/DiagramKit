import Testing
import Foundation
@testable import DiagramKitPlantUML

@Suite struct PlantUMLTreeViewRecoveryMarkerTests {
    @Test func descriptionRoundTrip() {
        let body = "primitive value with ; and \" chars"
        let line = PlantUMLRecoveryMarker.emitTreeViewNodeDescription(nodeId: 3, body: body)
        #expect(line.hasPrefix("' diagramkit:treeview-node-description=3,b64:"))

        let markers = PlantUMLRecoveryMarker.scanner.scan(source: line + "\n").markers
        #expect(markers.count == 1)
        if case .treeViewNodeDescription(let nodeId, let b64) = markers[0].kind {
            #expect(nodeId == 3)
            let decoded = Data(base64Encoded: b64).flatMap { String(data: $0, encoding: .utf8) }
            #expect(decoded == body)
        } else {
            Issue.record("expected treeViewNodeDescription marker, got \(markers[0].kind)")
        }
    }

    @Test func iconRoundTrip() {
        let line = PlantUMLRecoveryMarker.emitTreeViewNodeIcon(nodeId: 5, iconId: "folder")
        #expect(line == "' diagramkit:treeview-node-icon=5,folder")

        let markers = PlantUMLRecoveryMarker.scanner.scan(source: line + "\n").markers
        #expect(markers.count == 1)
        #expect(markers[0].kind == .treeViewNodeIcon(nodeId: 5, iconId: "folder"))
    }

    @Test func cssClassRoundTrip() {
        let line = PlantUMLRecoveryMarker.emitTreeViewNodeCssClass(nodeId: 7, cssClass: "highlighted")
        #expect(line == "' diagramkit:treeview-node-cssclass=7,highlighted")

        let markers = PlantUMLRecoveryMarker.scanner.scan(source: line + "\n").markers
        #expect(markers.count == 1)
        #expect(markers[0].kind == .treeViewNodeCssClass(nodeId: 7, cssClass: "highlighted"))
    }

    @Test func malformedNodeIdReturnsNil() {
        let bogus = "' diagramkit:treeview-node-icon=not-an-int,folder\n"
        let markers = PlantUMLRecoveryMarker.scanner.scan(source: bogus).markers
        #expect(markers.isEmpty)
    }
}
