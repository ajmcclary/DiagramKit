import Testing
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel
@testable import DiagramKitPlantUML

@Suite("PlantUMLDeploymentRoundTripTests")
struct PlantUMLDeploymentRoundTripTests {

    @Test func roundTripPreservesStereotype() throws {
        let source = #"""
        @startuml
        node "Worker" as worker <<router>>
        @enduml
        """#
        let exported = try roundTrip(source)
        #expect(exported.contains("<<router>>") || exported.contains("deployment-service-stereotype=worker,router"))
    }

    @Test func roundTripPreservesColor() throws {
        let source = #"""
        @startuml
        database "DB" as db #FF6600
        @enduml
        """#
        let exported = try roundTrip(source)
        #expect(exported.contains("#FF6600") || exported.contains("deployment-service-color=db,#FF6600"))
    }

    @Test func roundTripPreservesGroupKind() throws {
        let source = #"""
        @startuml
        cloud "AWS" as aws {
          node "EC2" as ec2
        }
        @enduml
        """#
        let exported = try roundTrip(source)
        #expect(exported.contains(#"cloud "AWS""#) || exported.contains("deployment-group-kind=aws,cloud"))
    }

    @Test func roundTripPreservesEdgeDashedStyle() throws {
        let source = #"""
        @startuml
        node "A" as a
        node "B" as b
        a ..> b : depends
        @enduml
        """#
        let exported = try roundTrip(source)
        #expect(exported.contains("..>") || exported.contains("deployment-edge-style=0,dashed"))
    }

    @Test func roundTripPreservesNote() throws {
        let source = #"""
        @startuml
        node "Worker" as worker
        note right of worker
        Handles all incoming traffic.
        end note
        @enduml
        """#
        let exported = try roundTrip(source)
        #expect(exported.contains("Handles all incoming traffic") || exported.contains("deployment-note=worker,right,b64:"))
    }

    @Test func roundTripPreservesLegend() throws {
        let source = #"""
        @startuml
        node "X" as x
        legend
        Requires VPN access
        endlegend
        @enduml
        """#
        let exported = try roundTrip(source)
        #expect(exported.contains("Requires VPN access") || exported.contains("deployment-legend=b64:"))
    }

    @Test func twoRoundTripsPreserveGroupKindExactly() throws {
        let source = #"""
        @startuml
        cloud "AWS" as aws {
          node "EC2" as ec2
        }
        @enduml
        """#
        let pass1 = try roundTrip(source)
        let parsed1 = try PlantUMLImporter().parse(pass1)
        guard case .architecture(let arch1) = parsed1.document.payload else {
            Issue.record("not architecture after pass 1"); return
        }
        let markers1 = arch1.recoveryMarkers.flatMap {
            PlantUMLRecoveryMarker.scanner.scan(source: $0).markers
        }
        let groupKind1 = markers1.compactMap { marker -> String? in
            if case let .deploymentGroupKind(id, raw) = marker.kind, id == "aws" { return raw }
            return nil
        }.first
        #expect(groupKind1 == "cloud", "group kind should survive round-trip; got \(String(describing: groupKind1))")
    }

    private func roundTrip(_ source: String) throws -> String {
        let parsed = try PlantUMLImporter().parse(source)
        return try PlantUMLExporter().export(parsed.document).source
    }
}
