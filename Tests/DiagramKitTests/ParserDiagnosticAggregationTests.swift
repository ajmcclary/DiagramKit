#if canImport(CoreGraphics)
import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKitModel
@testable import DiagramKit
@testable import DiagramKitRenderingCG

@Suite("Cross-tier diagnostic aggregation")
struct ParserDiagnosticAggregationTests {

    @Test("PreparedDiagram.diagnostics surfaces C4 \\$boundary parse warnings")
    func preparedDiagramSurfacesParseWarnings() throws {
        let source = """
        C4Context
        Boundary(other, "Other")
        Boundary(outer, "Outer") {
          System(s, "S") $boundary=other
        }
        """
        let prepared = try DiagramPipeline.prepare(source: source)
        #expect(prepared.diagnostics.contains { $0.severity == .warning })
    }

    @Test("PreparedDiagram aggregates import then layout diagnostics in order")
    func aggregationOrderIsImportThenLayout() throws {
        let doc = try DiagramPipeline.parse("pie\n  \"a\" : 1")
        var positioned = try GraphLayout().layout(doc)
        positioned.diagnostics = [
            DiagramDiagnostic(severity: .warning, message: "layout-warn", location: nil)
        ]
        let prepared = PreparedDiagram(
            positioned: positioned,
            theme: .default,
            importDiagnostics: [
                DiagramDiagnostic(severity: .warning, message: "import-warn", location: nil)
            ]
        )
        #expect(prepared.diagnostics.map(\.message) == ["import-warn", "layout-warn"])
    }
}
#endif
