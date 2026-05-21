import Testing
@testable import DiagramKitD2

@Suite("D2RecoveryMarker c4 cases")
struct D2RecoveryMarkerC4Tests {

    @Test func emitAndParseDiagramKind() {
        let line = D2RecoveryMarker.emitC4DiagramKind("C4Container")
        #expect(line == "# diagramkit:c4-diagram-kind=C4Container")
        #expect(parsed(line) == .c4DiagramKind(rawValue: "C4Container"))
    }

    @Test func emitAndParseShapeKind() {
        let line = D2RecoveryMarker.emitC4ShapeKind(targetID: "svc", rawValue: "container_db")
        #expect(line == "# diagramkit:c4-shape-kind=svc,container_db")
        #expect(parsed(line) == .c4ShapeKind(targetID: "svc", rawValue: "container_db"))
    }

    @Test func emitAndParseExternal() {
        let line = D2RecoveryMarker.emitC4External(targetID: "svc")
        #expect(line == "# diagramkit:c4-external=svc")
        #expect(parsed(line) == .c4External(targetID: "svc"))
    }

    @Test func emitAndParseTechnology() {
        let line = D2RecoveryMarker.emitC4Technology(targetID: "svc", value: "Swift 6")
        #expect(line == "# diagramkit:c4-technology=svc,Swift 6")
        #expect(parsed(line) == .c4Technology(targetID: "svc", value: "Swift 6"))
    }

    @Test func emitAndParseDescription() {
        let line = D2RecoveryMarker.emitC4Description(targetID: "svc", value: "Auth service")
        #expect(line == "# diagramkit:c4-description=svc,Auth service")
        #expect(parsed(line) == .c4Description(targetID: "svc", value: "Auth service"))
    }

    @Test func emitAndParseSprite() {
        let line = D2RecoveryMarker.emitC4Sprite(targetID: "svc", value: "person")
        #expect(line == "# diagramkit:c4-sprite=svc,person")
        #expect(parsed(line) == .c4Sprite(targetID: "svc", value: "person"))
    }

    @Test func emitAndParseTag() {
        let line = D2RecoveryMarker.emitC4Tag(targetID: "svc", value: "internal,v2")
        #expect(line == "# diagramkit:c4-tag=svc,internal,v2")
        #expect(parsed(line) == .c4Tag(targetID: "svc", value: "internal,v2"))
    }

    @Test func emitAndParseLink() {
        let line = D2RecoveryMarker.emitC4Link(targetID: "svc", value: "https://example.com")
        #expect(line == "# diagramkit:c4-link=svc,https://example.com")
        #expect(parsed(line) == .c4Link(targetID: "svc", value: "https://example.com"))
    }

    @Test func emitAndParseBoundaryKind() {
        let line = D2RecoveryMarker.emitC4BoundaryKind(targetID: "b1", rawValue: "enterprise")
        #expect(line == "# diagramkit:c4-boundary-kind=b1,enterprise")
        #expect(parsed(line) == .c4BoundaryKind(targetID: "b1", rawValue: "enterprise"))
    }

    @Test func emitAndParseRelKind() {
        let line = D2RecoveryMarker.emitC4RelKind(edgeIndex: 3, rawValue: "rel_u")
        #expect(line == "# diagramkit:c4-rel-kind=3,rel_u")
        #expect(parsed(line) == .c4RelKind(edgeIndex: 3, rawValue: "rel_u"))
    }

    @Test func emitAndParseColor() {
        let line = D2RecoveryMarker.emitC4Color(
            targetID: "svc",
            packed: "bg=#fff;font=#000;border=#888"
        )
        #expect(line == "# diagramkit:c4-color=svc,bg=#fff;font=#000;border=#888")
        #expect(parsed(line) == .c4Color(targetID: "svc", packed: "bg=#fff;font=#000;border=#888"))
    }

    private func parsed(_ line: String) -> D2RecoveryMarker.Kind? {
        D2RecoveryMarker.scanner.scan(source: line).markers.first?.kind
    }
}
