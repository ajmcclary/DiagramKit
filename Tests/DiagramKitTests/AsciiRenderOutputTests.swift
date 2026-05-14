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
}
