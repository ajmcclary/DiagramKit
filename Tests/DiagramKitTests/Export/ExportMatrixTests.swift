import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
import DiagramKit
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitStructurizr
import DiagramKitPlantUML

@Suite struct ExportMatrixTests {

    // MARK: - Mermaid exporter

    @Test("Mermaid exporter supports flowchart, sequence, class, ER, C4, gantt, state")
    func mermaidExporterSupportedTypes() {
        let exporter = MermaidExporter()
        #expect(exporter.supportedDiagramTypes.contains(.flowchart))
        #expect(exporter.supportedDiagramTypes.contains(.sequenceDiagram))
        #expect(exporter.supportedDiagramTypes.contains(.classDiagram))
        #expect(exporter.supportedDiagramTypes.contains(.erDiagram))
        #expect(exporter.supportedDiagramTypes.contains(.c4))
        #expect(exporter.supportedDiagramTypes.contains(.gantt))
        #expect(exporter.supportedDiagramTypes.contains(.stateDiagram))
    }

    // MARK: - D2 exporter

    @Test("D2 exporter supports flowchart, classDiagram, stateDiagram, erDiagram")
    func d2ExporterSupportedTypes() {
        let exporter = D2Exporter()
        #expect(exporter.supportedDiagramTypes.contains(.flowchart))
        #expect(exporter.supportedDiagramTypes.contains(.classDiagram))
        #expect(exporter.supportedDiagramTypes.contains(.stateDiagram))
        #expect(exporter.supportedDiagramTypes.contains(.erDiagram))
        #expect(!exporter.supportedDiagramTypes.contains(.architecture))
        #expect(!exporter.supportedDiagramTypes.contains(.sequenceDiagram))
    }

    // MARK: - DOT exporter

    @Test("DOT exporter supports flowchart, classDiagram, stateDiagram")
    func dotExporterSupportedTypes() {
        let exporter = DOTExporter()
        #expect(exporter.supportedDiagramTypes.contains(.flowchart))
        #expect(exporter.supportedDiagramTypes.contains(.classDiagram))
        #expect(exporter.supportedDiagramTypes.contains(.stateDiagram))
        #expect(!exporter.supportedDiagramTypes.contains(.sequenceDiagram))
    }

    // MARK: - Structurizr exporter

    @Test("Structurizr exporter supports c4 only")
    func structurizrExporterSupportedTypes() {
        let exporter = StructurizrExporter()
        #expect(exporter.supportedDiagramTypes.contains(.c4))
        #expect(!exporter.supportedDiagramTypes.contains(.flowchart))
        #expect(!exporter.supportedDiagramTypes.contains(.sequenceDiagram))
    }

    // MARK: - PlantUML exporter

    @Test("PlantUML exporter covers Phase 6 base + Wave 1 expansions (activity → flowchart, ER, architecture)")
    func plantUMLExporterSupportedTypes() {
        let exporter = PlantUMLExporter()
        #expect(exporter.supportedDiagramTypes.contains(.sequenceDiagram))
        #expect(exporter.supportedDiagramTypes.contains(.classDiagram))
        #expect(exporter.supportedDiagramTypes.contains(.stateDiagram))
        #expect(exporter.supportedDiagramTypes.contains(.mindmap))
        #expect(exporter.supportedDiagramTypes.contains(.gantt))
        #expect(exporter.supportedDiagramTypes.contains(.c4))
        #expect(exporter.supportedDiagramTypes.contains(.flowchart))
        #expect(exporter.supportedDiagramTypes.contains(.erDiagram))
        #expect(exporter.supportedDiagramTypes.contains(.architecture))
    }

    // MARK: - Unsupported type diagnostic

    @Test("Unsupported type produces diagnostic, not empty source")
    func unsupportedTypeProducesDiagnostic() throws {
        let exporter = StructurizrExporter() // c4 only
        let doc = DiagramDocument(type: .gantt) // gantt is not c4
        let result = try exporter.export(doc)
        #expect(result.source.isEmpty)
        #expect(!result.diagnostics.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .unsupported })
    }

    @Test("No exporter silently returns empty source with zero diagnostics")
    func noSilentEmptyOutput() throws {
        let exporters: [any DiagramExporter] = [
            MermaidExporter(),
            D2Exporter(),
            DOTExporter(),
            StructurizrExporter(),
            PlantUMLExporter()
        ]
        for exporter in exporters {
            for type in DiagramType.allCases
                where !exporter.supportedDiagramTypes.contains(type)
            {
                let doc = DiagramDocument(type: type)
                let result = try exporter.export(doc)
                #expect(result.source.isEmpty,
                    "\(exporter.name) should produce empty source for unsupported type \(type.rawValue)")
                #expect(result.diagnostics.contains { $0.severity == .unsupported },
                    "\(exporter.name) should produce .unsupported diagnostic for type \(type.rawValue)")
            }
        }
    }

    // MARK: - Registry lookup

    @Test("Exporter registry lookup by format ID")
    func registryLookupByFormatID() {
        let registry = DiagramPipeline.defaultExportRegistry
        #expect(registry.exporter(named: .mermaid) != nil)
        #expect(registry.exporter(named: .d2) != nil)
        #expect(registry.exporter(named: .structurizr) != nil)
        #expect(registry.exporter(named: .plantuml) != nil)
        #expect(registry.exporter(named: .graphviz) != nil)
    }
}
