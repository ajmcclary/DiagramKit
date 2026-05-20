import Testing
@testable import DiagramKitD2

@Suite("D2 recovery marker")
struct D2RecoveryMarkerTests {

    @Test("parses class-stereotype marker")
    func parsesClassStereotype() {
        let source = "# diagramkit:class-stereotype=Order,<<entity>>"
        let result = D2RecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .classStereotype(className: "Order", stereotype: "<<entity>>"))
    }

    @Test("parses state-action marker")
    func parsesStateAction() {
        let source = "# diagramkit:state-action=Active,entry,place_order"
        let result = D2RecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .stateAction(
            ownerStateId: "Active",
            phase: .entry,
            label: "place_order"
        ))
    }

    @Test("parses er-cardinality marker")
    func parsesERCardinality() {
        let source = "# diagramkit:er-cardinality=r0,one,zero-or-many"
        let result = D2RecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .erCardinality(
            relationshipId: "r0",
            source: "one",
            target: "zero-or-many"
        ))
    }

    @Test("emits valid class-stereotype line")
    func emitsClassStereotype() {
        let line = D2RecoveryMarker.emitClassStereotype(className: "Order", stereotype: "<<entity>>")
        #expect(line == "# diagramkit:class-stereotype=Order,<<entity>>")
    }

    @Test("emits valid state-action line")
    func emitsStateAction() {
        let line = D2RecoveryMarker.emitStateAction(ownerStateId: "Active", phase: .entry, label: "place_order")
        #expect(line == "# diagramkit:state-action=Active,entry,place_order")
    }

    @Test("emits valid er-cardinality line")
    func emitsERCardinality() {
        let line = D2RecoveryMarker.emitERCardinality(relationshipId: "r0", source: "one", target: "zero-or-many")
        #expect(line == "# diagramkit:er-cardinality=r0,one,zero-or-many")
    }
}
