import Testing
@testable import DiagramKitGraphviz

@Suite("DOTRecoveryMarker c4 cases")
struct DOTRecoveryMarkerC4Tests {

    @Test func emitAndParseDiagramKind() {
        let line = DOTRecoveryMarker.emitC4DiagramKind("C4Container")
        #expect(line == "# diagramkit:c4-diagram-kind=C4Container")
        #expect(parsed(line) == .c4DiagramKind(rawValue: "C4Container"))
    }

    @Test func emitAndParseShapeKind() {
        let line = DOTRecoveryMarker.emitC4ShapeKind(targetID: "svc", rawValue: "container_db")
        #expect(line == "# diagramkit:c4-shape-kind=svc,container_db")
        #expect(parsed(line) == .c4ShapeKind(targetID: "svc", rawValue: "container_db"))
    }

    @Test func emitAndParseExternal() {
        let line = DOTRecoveryMarker.emitC4External(targetID: "svc")
        #expect(line == "# diagramkit:c4-external=svc")
        #expect(parsed(line) == .c4External(targetID: "svc"))
    }

    @Test func emitAndParseTechnology() {
        let line = DOTRecoveryMarker.emitC4Technology(targetID: "svc", value: "Swift 6")
        #expect(line == "# diagramkit:c4-technology=svc,Swift 6")
        #expect(parsed(line) == .c4Technology(targetID: "svc", value: "Swift 6"))
    }

    @Test func emitAndParseDescription() {
        let line = DOTRecoveryMarker.emitC4Description(targetID: "svc", value: "Auth service")
        #expect(line == "# diagramkit:c4-description=svc,Auth service")
        #expect(parsed(line) == .c4Description(targetID: "svc", value: "Auth service"))
    }

    @Test func emitAndParseSprite() {
        let line = DOTRecoveryMarker.emitC4Sprite(targetID: "svc", value: "person")
        #expect(line == "# diagramkit:c4-sprite=svc,person")
        #expect(parsed(line) == .c4Sprite(targetID: "svc", value: "person"))
    }

    @Test func emitAndParseTag() {
        let line = DOTRecoveryMarker.emitC4Tag(targetID: "svc", value: "internal,v2")
        #expect(line == "# diagramkit:c4-tag=svc,internal,v2")
        #expect(parsed(line) == .c4Tag(targetID: "svc", value: "internal,v2"))
    }

    @Test func emitAndParseLink() {
        let line = DOTRecoveryMarker.emitC4Link(targetID: "svc", value: "https://example.com")
        #expect(line == "# diagramkit:c4-link=svc,https://example.com")
        #expect(parsed(line) == .c4Link(targetID: "svc", value: "https://example.com"))
    }

    @Test func emitAndParseBoundaryKind() {
        let line = DOTRecoveryMarker.emitC4BoundaryKind(targetID: "b1", rawValue: "enterprise")
        #expect(line == "# diagramkit:c4-boundary-kind=b1,enterprise")
        #expect(parsed(line) == .c4BoundaryKind(targetID: "b1", rawValue: "enterprise"))
    }

    @Test func emitAndParseRelKind() {
        let line = DOTRecoveryMarker.emitC4RelKind(edgeIndex: 3, rawValue: "rel_u")
        #expect(line == "# diagramkit:c4-rel-kind=3,rel_u")
        #expect(parsed(line) == .c4RelKind(edgeIndex: 3, rawValue: "rel_u"))
    }

    @Test func emitAndParseColor() {
        let line = DOTRecoveryMarker.emitC4Color(
            targetID: "svc",
            packed: "bg=#fff;font=#000;border=#888"
        )
        #expect(line == "# diagramkit:c4-color=svc,bg=#fff;font=#000;border=#888")
        #expect(parsed(line) == .c4Color(targetID: "svc", packed: "bg=#fff;font=#000;border=#888"))
    }

    private func parsed(_ line: String) -> DOTRecoveryMarker.Kind? {
        DOTRecoveryMarker.scanner.scan(source: line).markers.first?.kind
    }
}
