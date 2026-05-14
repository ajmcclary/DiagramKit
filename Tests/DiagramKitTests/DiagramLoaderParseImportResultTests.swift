import Testing
import DiagramKitCommon
import DiagramKitImport
@testable import DiagramKit

@Suite("DiagramLoader.parseImportResult")
struct DiagramLoaderParseImportResultTests {

    @Test("Returns full DiagramImportResult including diagnostics from C4 $boundary mismatch")
    func returnsFullImportResultWithDiagnostics() throws {
        let source = """
        C4Context
        Boundary(other, "Other")
        Boundary(outer, "Outer") {
          System(s, "S") $boundary=other
        }
        """
        let result = try DiagramLoader.parseImportResult(
            source,
            registry: DiagramPipeline.defaultRegistry
        )
        #expect(result.document.type == .c4)
        #expect(result.diagnostics.contains { $0.severity == .warning })
    }

    @Test("parseDocument returns only the document portion")
    func parseDocumentRoutesThrough() throws {
        let source = "flowchart TD\nA --> B"
        let document = try DiagramLoader.parseDocument(
            source,
            registry: DiagramPipeline.defaultRegistry
        )
        #expect(document.type == .flowchart)
    }

    @Test("Empty source throws DiagramError.unrecognizedFormat")
    func emptySourceThrows() {
        #expect(throws: DiagramError.self) {
            _ = try DiagramLoader.parseImportResult(
                "",
                registry: DiagramPipeline.defaultRegistry
            )
        }
    }
}
