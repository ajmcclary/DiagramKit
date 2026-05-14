import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKit

@Suite("MermaidImporter populates diagnostics")
struct MermaidImporterDiagnosticsTests {
    @Test("C4 unresolved $boundary surfaces .warning")
    func c4UnresolvedBoundaryWarning() throws {
        let source = """
        C4Context
        title test
        Person(p, "User") $boundary=missing
        """
        let result = try MermaidImporter().parse(source)
        let messages = result.diagnostics.map(\.message)
        #expect(result.diagnostics.contains { $0.severity == .warning })
        #expect(messages.contains { $0.contains("missing") })
    }
}
