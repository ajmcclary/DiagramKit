import Testing
@testable import DiagramKitGraphviz

@Suite("DOT block probe")
struct DOTBlockProbeTests {

    @Test("Any block-* marker triggers detection")
    func anyBlockMarkerTriggers() {
        let source = """
        digraph G {
          a;
          # diagramkit:block-cols=root,2
        }
        """
        let markers = DOTRecoveryMarker.scanner.scan(source: source).markers
        #expect(DOTBlockProbe.detectsBlock(markers: markers) == true)
    }

    @Test("Marker-less DOT source does not trigger")
    func markerlessRejected() {
        let source = """
        digraph G { a -> b; }
        """
        let markers = DOTRecoveryMarker.scanner.scan(source: source).markers
        #expect(DOTBlockProbe.detectsBlock(markers: markers) == false)
    }

    @Test("c4 markers do not trigger block")
    func c4MarkersRejected() {
        let source = """
        # diagramkit:family=c4
        # diagramkit:c4-diagram-kind=C4Container
        digraph G { }
        """
        let markers = DOTRecoveryMarker.scanner.scan(source: source).markers
        #expect(DOTBlockProbe.detectsBlock(markers: markers) == false)
    }
}
