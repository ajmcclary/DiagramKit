import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKit

@Suite("PositionedGraph diagnostics")
struct PositionedGraphDiagnosticsTests {
    @Test("Default value is empty array")
    func defaultIsEmpty() throws {
        let doc = try DiagramPipeline.parse("pie\n  \"a\" : 1")
        let positioned = try GraphLayout().layout(doc)
        #expect(positioned.diagnostics == [])
    }

    @Test("Field is publicly mutable")
    func fieldIsMutable() throws {
        let doc = try DiagramPipeline.parse("pie\n  \"a\" : 1")
        var positioned = try GraphLayout().layout(doc)
        positioned.diagnostics = [
            DiagramDiagnostic(severity: .warning, message: "test", location: nil)
        ]
        #expect(positioned.diagnostics.count == 1)
        #expect(positioned.diagnostics[0].message == "test")
    }
}
