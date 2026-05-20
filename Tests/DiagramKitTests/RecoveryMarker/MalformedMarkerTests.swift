import Testing
@testable import DiagramKitCommon

@Suite("malformed marker emission")
struct MalformedMarkerTests {

    enum TestKind: Sendable, Equatable {
        case tag(String)
    }

    static func scanner() -> RecoveryMarkerScanner<TestKind> {
        RecoveryMarkerScanner<TestKind>(commentPrefix: "#") { rest in
            guard rest.hasPrefix("tag=") else { return nil }
            return .tag(String(rest.dropFirst(4)))
        }
    }

    @Test("scanWithDiagnostics emits one warning per malformed sentinel line")
    func emitsMalformedDiagnostic() {
        let source = """
        # diagramkit:tag=ok
        # diagramkit:not-a-recognized-kind=value
        """
        let (result, diagnostics) = Self.scanner().scanWithDiagnostics(source: source)
        #expect(result.markers.count == 1)
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].severity == .warning)
        #expect(diagnostics[0].message.contains("line 2"))
    }

    @Test("scanWithDiagnostics emits zero diagnostics on a clean source")
    func emitsNoneOnCleanSource() {
        let source = "# diagramkit:tag=ok"
        let (_, diagnostics) = Self.scanner().scanWithDiagnostics(source: source)
        #expect(diagnostics.isEmpty)
    }

    @Test("scanWithDiagnostics ignores non-sentinel comments")
    func ignoresPlainComments() {
        let source = "# just a regular comment"
        let (result, diagnostics) = Self.scanner().scanWithDiagnostics(source: source)
        #expect(result.markers.isEmpty)
        #expect(diagnostics.isEmpty)
    }
}
