import Testing
@testable import DiagramKitD2

@Suite("D2RecoveryMarker — sequence kinds")
struct D2RecoveryMarkerSequenceTests {

    @Test("seqActorKind round-trips emit → scanner → parse")
    func seqActorKindRoundTrip() throws {
        let line = D2RecoveryMarker.emitSeqActorKind(actorID: "alice", participantType: "actor")
        let markers = D2RecoveryMarker.scanner.scan(source: line).markers
        try #require(markers.count == 1)
        guard case .seqActorKind(let id, let kind) = markers[0].kind else {
            Issue.record("expected seqActorKind, got \(markers[0].kind)")
            return
        }
        #expect(id == "alice")
        #expect(kind == "actor")
    }

    @Test("seqArrowType round-trips with integer index and rawValue")
    func seqArrowTypeRoundTrip() throws {
        let line = D2RecoveryMarker.emitSeqArrowType(messageIndex: 3, rawValue: 24)
        let markers = D2RecoveryMarker.scanner.scan(source: line).markers
        guard case .seqArrowType(let idx, let raw) = markers[0].kind else {
            Issue.record("wrong kind"); return
        }
        #expect(idx == 3)
        #expect(raw == 24)
    }

    @Test("seqMessageAttr carries attr verbatim")
    func seqMessageAttrRoundTrip() throws {
        let line = D2RecoveryMarker.emitSeqMessageAttr(messageIndex: 1, attr: "activate")
        let markers = D2RecoveryMarker.scanner.scan(source: line).markers
        guard case .seqMessageAttr(let idx, let attr) = markers[0].kind else {
            Issue.record("wrong kind"); return
        }
        #expect(idx == 1)
        #expect(attr == "activate")
    }

    @Test("seqBlockType pins block type for a container label")
    func seqBlockTypeRoundTrip() throws {
        let line = D2RecoveryMarker.emitSeqBlockType(containerLabel: "alt_1", blockType: "alt")
        let markers = D2RecoveryMarker.scanner.scan(source: line).markers
        guard case .seqBlockType(let label, let type) = markers[0].kind else {
            Issue.record("wrong kind"); return
        }
        #expect(label == "alt_1")
        #expect(type == "alt")
    }

    @Test("seqBlockDivider preserves index and label")
    func seqBlockDividerRoundTrip() throws {
        let line = D2RecoveryMarker.emitSeqBlockDivider(containerLabel: "alt_1", dividerIndex: 2, label: "no path")
        let markers = D2RecoveryMarker.scanner.scan(source: line).markers
        guard case .seqBlockDivider(let label, let idx, let dLabel) = markers[0].kind else {
            Issue.record("wrong kind"); return
        }
        #expect(label == "alt_1")
        #expect(idx == 2)
        #expect(dLabel == "no path")
    }

    @Test("seqNote preserves position, actors and text")
    func seqNoteRoundTrip() throws {
        let line = D2RecoveryMarker.emitSeqNote(
            afterMessageIndex: 1,
            position: "right of",
            actorIDsCsv: "bob",
            text: "Thinking..."
        )
        let markers = D2RecoveryMarker.scanner.scan(source: line).markers
        guard case .seqNote(let after, let pos, let csv, let text) = markers[0].kind else {
            Issue.record("wrong kind"); return
        }
        #expect(after == 1)
        #expect(pos == "right of")
        #expect(csv == "bob")
        #expect(text == "Thinking...")
    }

    @Test("seqBox preserves fill / wrap / name")
    func seqBoxRoundTrip() throws {
        let line = D2RecoveryMarker.emitSeqBox(
            containerLabel: "customerBox",
            fill: "#ECECFF",
            wrap: true,
            name: "Customer side"
        )
        let markers = D2RecoveryMarker.scanner.scan(source: line).markers
        guard case .seqBox(let label, let fill, let wrap, let name) = markers[0].kind else {
            Issue.record("wrong kind"); return
        }
        #expect(label == "customerBox")
        #expect(fill == "#ECECFF")
        #expect(wrap == true)
        #expect(name == "Customer side")
    }

    @Test("seqAutonumber preserves start / step / visible")
    func seqAutonumberRoundTrip() throws {
        let line = D2RecoveryMarker.emitSeqAutonumber(start: 5.0, step: 10.0, visible: true)
        let markers = D2RecoveryMarker.scanner.scan(source: line).markers
        guard case .seqAutonumber(let start, let step, let visible) = markers[0].kind else {
            Issue.record("wrong kind"); return
        }
        #expect(start == 5.0)
        #expect(step == 10.0)
        #expect(visible == true)
    }

    @Test("seqTitle / seqAccTitle / seqAccDescr carry text verbatim")
    func titleMarkerRoundTrip() throws {
        let titleLine = D2RecoveryMarker.emitSeqTitle("Login flow")
        let titleMarkers = D2RecoveryMarker.scanner.scan(source: titleLine).markers
        guard case .seqTitle(let t) = titleMarkers[0].kind else { Issue.record("wrong kind"); return }
        #expect(t == "Login flow")

        let accTitleLine = D2RecoveryMarker.emitSeqAccTitle("Login")
        guard case .seqAccTitle(let at) = D2RecoveryMarker.scanner.scan(source: accTitleLine).markers[0].kind else {
            Issue.record("wrong kind"); return
        }
        #expect(at == "Login")

        let accDescrLine = D2RecoveryMarker.emitSeqAccDescr("OAuth flow")
        guard case .seqAccDescr(let ad) = D2RecoveryMarker.scanner.scan(source: accDescrLine).markers[0].kind else {
            Issue.record("wrong kind"); return
        }
        #expect(ad == "OAuth flow")
    }
}
