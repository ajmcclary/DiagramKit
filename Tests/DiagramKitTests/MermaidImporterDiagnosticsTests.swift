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

    @Test("Kanban duplicate node ID surfaces .warning")
    func kanbanDuplicateNodeWarning() throws {
        let source = """
        kanban
            col1[Column 1]
                t1[Task]
            col2[Column 2]
                t1[Task again]
        """
        let result = try MermaidImporter().parse(source)
        let messages = result.diagnostics.map(\.message)
        #expect(result.diagnostics.contains { $0.severity == .warning })
        #expect(messages.contains { $0.contains("duplicate") && $0.contains("t1") })
    }
}
