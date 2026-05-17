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

    @Test("DiagramEngine.parseImportResult surfaces diagnostics async")
    func engineParseImportResult() async throws {
        let source = """
        C4Context
        Boundary(other, "Other")
        Boundary(outer, "Outer") {
          System(s, "S") $boundary=other
        }
        """
        let result = try await DiagramEngine.parseImportResult(source: source)
        #expect(result.document.type == .c4)
        #expect(result.diagnostics.contains { $0.severity == .warning })
    }

    @Test("DiagramPipeline.parseImportResult routes through the centralized boundary")
    func pipelineParseImportResultRoutes() throws {
        let source = """
        C4Context
        Boundary(other, "Other")
        Boundary(outer, "Outer") {
          System(s, "S") $boundary=other
        }
        """
        let viaPipeline = try DiagramPipeline.parseImportResult(source)
        let viaLoader = try DiagramLoader.parseImportResult(source, registry: DiagramPipeline.defaultRegistry)
        // Result equivalence — DiagramPipeline.parseImportResult is the
        // documented entry point and must match DiagramLoader directly
        // while additionally applying font registration / issue reporting.
        #expect(viaPipeline.document.type == viaLoader.document.type)
        #expect(viaPipeline.diagnostics == viaLoader.diagnostics)
    }

    @Test("DiagramPipeline.parseImportResult honors explicit sourceFormat")
    func pipelineParseImportResultRespectsSourceFormat() throws {
        let source = "flowchart TD\nA --> B"
        let result = try DiagramPipeline.parseImportResult(source, sourceFormat: .mermaid)
        #expect(result.document.type == .flowchart)
    }
}
