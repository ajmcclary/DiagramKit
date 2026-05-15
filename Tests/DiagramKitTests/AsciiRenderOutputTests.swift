import Testing
import DiagramKitCommon
import DiagramKit

@Suite("AsciiRenderOutput")
struct AsciiRenderOutputTests {
    @Test("Stores text and diagnostics")
    func storesFields() {
        let output = AsciiRenderOutput(text: "hello", diagnostics: [])
        #expect(output.text == "hello")
        #expect(output.diagnostics == [])
    }

    @Test("Diagnostics preserved in order")
    func diagnosticsPreservedInOrder() {
        let diags = [
            DiagramDiagnostic(severity: .warning, message: "first", location: nil),
            DiagramDiagnostic(severity: .warning, message: "second", location: nil)
        ]
        let output = AsciiRenderOutput(text: "x", diagnostics: diags)
        #expect(output.diagnostics.map(\.message) == ["first", "second"])
    }

    @Test("C4 ASCII renderASCII surfaces \\$boundary diagnostics")
    func c4AsciiSurfacesDiagnostics() async throws {
        let source = """
        C4Context
        Boundary(other, "Other")
        Boundary(outer, "Outer") {
          System(s, "S") $boundary=other
        }
        """
        let output = try await DiagramEngine.renderASCII(source: source)
        #expect(output.diagnostics.contains { $0.severity == .warning })
    }

    @Test("D2 ASCII routes through importer before Mermaid ASCII rendering")
    func d2AsciiRoutesThroughImporter() async throws {
        let output = try await DiagramEngine.renderASCII(source: "A -> B")

        #expect(!output.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(output.text.contains("A"))
        #expect(output.text.contains("B"))
    }
}
