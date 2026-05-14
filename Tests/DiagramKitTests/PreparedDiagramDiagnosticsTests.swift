#if canImport(CoreGraphics)
import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitRenderingCG
@testable import DiagramKit

@Suite("PreparedDiagram diagnostics aggregation")
struct PreparedDiagramDiagnosticsTests {
    @Test("Default aggregates empty + empty into empty")
    func defaultIsEmpty() throws {
        let doc = try DiagramPipeline.parse("pie\n  \"a\" : 1")
        let positioned = try GraphLayout().layout(doc)
        let prepared = PreparedDiagram(positioned: positioned, theme: .default)
        #expect(prepared.diagnostics == [])
    }

    @Test("importDiagnostics + positioned.diagnostics aggregate in order")
    func aggregatesInOrder() throws {
        let doc = try DiagramPipeline.parse("pie\n  \"a\" : 1")
        var positioned = try GraphLayout().layout(doc)
        positioned.diagnostics = [
            DiagramDiagnostic(severity: .warning, message: "layout-1", location: nil),
            DiagramDiagnostic(severity: .warning, message: "layout-2", location: nil)
        ]
        let importDiag = [
            DiagramDiagnostic(severity: .warning, message: "parse-1", location: nil)
        ]
        let prepared = PreparedDiagram(
            positioned: positioned,
            theme: .default,
            importDiagnostics: importDiag
        )
        #expect(prepared.diagnostics.map(\.message) == ["parse-1", "layout-1", "layout-2"])
    }
}
#endif
