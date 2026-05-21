import Testing
@testable import DiagramKitD2

@Suite("D2 block probe")
struct D2BlockProbeTests {

    @Test("Any block-* marker triggers detection")
    func anyBlockMarkerTriggers() {
        let source = """
        a: "A"
        # diagramkit:block-cols=root,2
        """
        let markers = D2RecoveryMarker.scanner.scan(source: source).markers
        #expect(D2BlockProbe.detectsBlock(markers: markers) == true)
    }

    @Test("block-class-apply marker triggers detection")
    func classApplyTriggers() {
        let source = """
        a: "A"
        # diagramkit:block-class-apply=a,blue
        """
        let markers = D2RecoveryMarker.scanner.scan(source: source).markers
        #expect(D2BlockProbe.detectsBlock(markers: markers) == true)
    }

    @Test("Marker-less D2 source does not trigger")
    func markerlessRejected() {
        let source = """
        a -> b
        """
        let markers = D2RecoveryMarker.scanner.scan(source: source).markers
        #expect(D2BlockProbe.detectsBlock(markers: markers) == false)
    }

    @Test("c4 markers do not trigger block")
    func c4MarkersRejected() {
        let source = """
        # diagramkit:family=c4
        # diagramkit:c4-diagram-kind=C4Container
        """
        let markers = D2RecoveryMarker.scanner.scan(source: source).markers
        #expect(D2BlockProbe.detectsBlock(markers: markers) == false)
    }

    @Test("family=block marker alone does NOT trigger (handled upstream)")
    func familyMarkerAloneRejected() {
        let source = """
        # diagramkit:family=block
        a: "A"
        """
        let markers = D2RecoveryMarker.scanner.scan(source: source).markers
        // The family marker is matched upstream by D2Importer via
        // markerScan. The probe only fires on block-* kinds.
        #expect(D2BlockProbe.detectsBlock(markers: markers) == false)
    }
}
