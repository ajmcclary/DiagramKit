import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// A mock exporter for testing registry and loader behavior.
private struct MockExporter: DiagramExporter {
    let name: String
    let formatID: DiagramFormatID
    let supportedDiagramTypes: Set<DiagramType>

    init(name: String, formatID: DiagramFormatID, supportedDiagramTypes: Set<DiagramType>) {
        self.name = name
        self.formatID = formatID
        self.supportedDiagramTypes = supportedDiagramTypes
    }

    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        if supportedDiagramTypes.contains(document.type) {
            return DiagramExportResult(source: "mock:\(document.type.rawValue)")
        }
        return DiagramExportResult(
            source: "",
            diagnostics: [
                DiagramDiagnostic(severity: .unsupported, message: "unsupported by \(name)")
            ]
        )
    }
}

@Suite struct ExporterRegistryTests {

    @Test("Registry stores and retrieves exporters by format ID")
    func registryLookup() {
        let mock = MockExporter(name: "Mock", formatID: .mermaid, supportedDiagramTypes: [.flowchart])
        var registry = ExporterRegistry.empty
        registry = registry.registering(mock)

        #expect(registry.exporter(named: .mermaid)?.name == "Mock")
        #expect(registry.exporter(named: .d2) == nil)

        let exporters = registry.exporters
        #expect(exporters.count == 1)
    }

    @Test("Registry replaces existing exporter with same format ID")
    func registryReplacement() {
        let mock1 = MockExporter(name: "Mock1", formatID: .mermaid, supportedDiagramTypes: [.flowchart])
        let mock2 = MockExporter(name: "Mock2", formatID: .mermaid, supportedDiagramTypes: [.flowchart, .sequenceDiagram])

        var registry = ExporterRegistry.empty
        registry = registry.registering(mock1)
        registry = registry.registering(mock2)

        #expect(registry.exporters.count == 1)
        #expect(registry.exporter(named: .mermaid)?.name == "Mock2")
    }

    @Test("Registry tracks union of supported diagram types")
    func registrySupportedTypes() {
        let mock1 = MockExporter(name: "M1", formatID: DiagramFormatID(rawValue: "f1"), supportedDiagramTypes: [.flowchart])
        let mock2 = MockExporter(name: "M2", formatID: DiagramFormatID(rawValue: "f2"), supportedDiagramTypes: [.sequenceDiagram, .c4])

        var registry = ExporterRegistry.empty
        registry = registry.registering(mock1)
        registry = registry.registering(mock2)

        #expect(registry.supportedDiagramTypes.contains(.flowchart))
        #expect(registry.supportedDiagramTypes.contains(.sequenceDiagram))
        #expect(registry.supportedDiagramTypes.contains(.c4))
        #expect(!registry.supportedDiagramTypes.contains(.gantt))
    }
}
