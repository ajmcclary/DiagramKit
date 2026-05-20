import Testing
@testable import DiagramKitCommon

@Suite("RecoveryMarkerScanner")
struct RecoveryMarkerScannerTests {

    enum TestKind: Sendable, Equatable {
        case tag(String)
    }

    static func scanner() -> RecoveryMarkerScanner<TestKind> {
        RecoveryMarkerScanner<TestKind>(commentPrefix: "#") { rest in
            guard rest.hasPrefix("tag=") else { return nil }
            return .tag(String(rest.dropFirst(4)))
        }
    }

    @Test("scans a single marker at expected line")
    func scansSingleMarker() {
        let source = """
        person customer "Customer"
        # diagramkit:tag=external
        """
        let result = Self.scanner().scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].lineNumber == 2)
        #expect(result.markers[0].kind == .tag("external"))
    }

    @Test("ignores non-marker comments")
    func ignoresPlainComments() {
        let source = """
        # this is a note
        # diagramkit:tag=foo
        """
        let result = Self.scanner().scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .tag("foo"))
    }

    @Test("strips leading and trailing whitespace")
    func stripsWhitespace() {
        let source = "   # diagramkit:tag=value   "
        let result = Self.scanner().scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .tag("value"))
    }

    @Test("ignores wrong comment prefix")
    func ignoresWrongPrefix() {
        let source = "// diagramkit:tag=foo"
        let result = Self.scanner().scan(source: source)
        #expect(result.markers.isEmpty)
    }

    @Test("returns lines for downstream correlation")
    func returnsLines() {
        let source = "line1\nline2\nline3"
        let result = Self.scanner().scan(source: source)
        #expect(result.lines == ["line1", "line2", "line3"])
    }
}
