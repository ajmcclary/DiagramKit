import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
import DiagramKit

/// A mock exporter that only supports flowchart.
private struct FlowchartOnlyExporter: DiagramExporter {
    let name = "FlowchartOnly"
    let formatID = DiagramFormatID(rawValue: "mock-flow")
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart]

    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        if document.type == .flowchart {
            return DiagramExportResult(source: "graph TD\n")
        }
        return DiagramExportResult(
            source: "",
            diagnostics: [DiagramDiagnostic(severity: .unsupported, message: "unsupported")]
        )
    }
}

@Suite struct DiagramExportLoaderTests {

    @Test("Loader dispatches to correct exporter by format ID")
    func loaderDispatch() throws {
        let exporter = FlowchartOnlyExporter()
        let registry = ExporterRegistry.empty.registering(exporter)

        let doc = DiagramDocument(type: .flowchart)
        let result = try DiagramExportLoader.export(doc, to: exporter.formatID, registry: registry)

        #expect(result.source == "graph TD\n")
        #expect(result.diagnostics.isEmpty)
    }

    @Test("Loader returns diagnostic for unsupported diagram type")
    func loaderUnsupportedType() throws {
        let exporter = FlowchartOnlyExporter()
        let registry = ExporterRegistry.empty.registering(exporter)

        let doc = DiagramDocument(type: .sequenceDiagram)
        let result = try DiagramExportLoader.export(doc, to: exporter.formatID, registry: registry)

        #expect(result.source.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .unsupported })
    }

    @Test("Loader returns unsupported diagnostic for unknown format ID")
    func loaderUnknownFormat() throws {
        let registry = ExporterRegistry.empty
        let doc = DiagramDocument(type: .flowchart)

        let result = try DiagramExportLoader.export(doc, to: .d2, registry: registry)

        #expect(result.source.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .unsupported })
    }

    @Test("Loader finds exporter by name")
    func loaderByName() throws {
        let exporter = FlowchartOnlyExporter()
        let registry = ExporterRegistry.empty.registering(exporter)

        let doc = DiagramDocument(type: .flowchart)
        let result = try DiagramExportLoader.export(doc, using: exporter.name, registry: registry)

        #expect(result.source == "graph TD\n")
    }

    @Test("Loader throws for unknown exporter name")
    func loaderUnknownName() {
        let registry = ExporterRegistry.empty
        let doc = DiagramDocument(type: .flowchart)

        #expect(throws: DiagramExportError.self) {
            try DiagramExportLoader.export(doc, using: "Not exist", registry: registry)
        }
    }

    @Test("DiagramExportLoader emits DOT source for graphviz format")
    func graphvizExportSucceeds() throws {
        let graph = ParsedGraphModel(
            direction: .TB,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "A", shape: .rectangle))
            ],
            edges: []
        )
        let doc = DiagramDocument(payload: .flowchart(graph))
        let result = try DiagramExportLoader.export(
            doc,
            to: .graphviz,
            registry: DiagramPipeline.defaultExportRegistry
        )
        #expect(result.source.contains("digraph G {"))
        #expect(result.diagnostics.allSatisfy { $0.severity != .unsupported })
    }
}
