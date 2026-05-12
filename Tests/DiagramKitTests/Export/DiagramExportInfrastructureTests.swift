import Testing
import DiagramKitModel
import DiagramKitImport
@testable import DiagramKitExport

@Suite struct DiagramExportInfrastructureTests {

    @Test("DiagramFormatID equality and raw values")
    func formatIDEquality() {
        #expect(DiagramFormatID.mermaid.rawValue == "mermaid")
        #expect(DiagramFormatID.d2.rawValue == "d2")
        #expect(DiagramFormatID.graphviz.rawValue == "graphviz")
        #expect(DiagramFormatID.structurizr.rawValue == "structurizr")
        #expect(DiagramFormatID.plantuml.rawValue == "plantuml")

        #expect(DiagramFormatID(rawValue: "mermaid") == .mermaid)
        #expect(DiagramFormatID(rawValue: "unknown").rawValue == "unknown")
    }

    @Test("DiagramExportResult stores source and diagnostics")
    func exportResultStorage() {
        let diag = DiagramDiagnostic(severity: .warning, message: "test")
        let result = DiagramExportResult(source: "test source", diagnostics: [diag])
        #expect(result.source == "test source")
        #expect(result.diagnostics.count == 1)
        #expect(result.diagnostics[0].message == "test")
    }

    @Test("DiagramExportError is a LocalizedError")
    func exportErrorDescription() {
        let error = DiagramExportError(message: "something went wrong")
        #expect(error.errorDescription == "something went wrong")
        #expect(error.localizedDescription == "something went wrong")
    }

    @Test("Empty registry has no exporters")
    func emptyRegistry() {
        let registry = ExporterRegistry.empty
        #expect(registry.exporters.isEmpty)
        #expect(registry.exporter(named: .mermaid) == nil)
        #expect(registry.supportedDiagramTypes.isEmpty)
    }
}
