import Testing
@testable import DiagramKit
import DiagramKitModel
import DiagramKitImport
import DiagramKitD2

@Suite struct ImporterRegistryTests {

    @Test("Default registry has D2 first, Mermaid last")
    func defaultRegistryOrder() throws {
        let registry = DiagramPipeline.defaultRegistry
        #expect(registry.importers.count >= 2)
        #expect(registry.importers[0].name == "D2")
        #expect(registry.importers.last?.name == "Mermaid")

        // d2-shaped source picks D2
        let d2Importer = try #require(registry.importer(for: "A -> B"))
        #expect(d2Importer.name == "D2")

        // Mermaid-shaped source picks Mermaid
        let mermaidImporter = try #require(registry.importer(for: "graph TD\nA-->B"))
        #expect(mermaidImporter.name == "Mermaid")
    }

    @Test("Empty registry returns nil importer")
    func emptyRegistryReturnsNil() {
        let registry = ImporterRegistry.empty
        #expect(registry.importer(for: "graph TD\nA-->B") == nil)
    }

    @Test("DiagramLoader throws when no importer matches")
    func loaderThrowsForUnsupportedSource() {
        let registry = ImporterRegistry.empty
        #expect(throws: DiagramError.self) {
            try DiagramLoader.parseDocument("unsupported", registry: registry)
        }
    }

    @Test("prepending() puts new importer first in probe order")
    func prependingPutsFirst() {
        let base = ImporterRegistry(importers: [MermaidImporter()])
        #expect(base.importers.count == 1)
        #expect(base.importers[0].name == "Mermaid")

        let d2 = D2Importer()
        let extended = base.prepending(d2)
        #expect(extended.importers.count == 2)
        #expect(extended.importers[0].name == "D2")
        #expect(extended.importers[1].name == "Mermaid")
    }

    @Test("layout(source:registry:) uses the importer registry")
    func layoutUsesImporterRegistry() throws {
        let registry = ImporterRegistry(importers: [FixtureImporter()])

        let positioned = try DiagramPipeline.layout("fixture-format source", registry: registry)

        #expect(positioned.diagram.type == .flowchart)
        #expect(positioned.flowchartNodes?.isEmpty == false)
    }

    #if canImport(CoreGraphics)
    @Test("prepare(source:registry:) uses the importer registry")
    func prepareUsesImporterRegistry() throws {
        let registry = ImporterRegistry(importers: [FixtureImporter()])

        let prepared = try DiagramPipeline.prepare(
            source: "fixture-format source",
            registry: registry
        )

        #expect(prepared.positioned.diagram.type == .flowchart)
        #expect(prepared.positioned.flowchartNodes?.isEmpty == false)
    }

    @Test("renderSVG(source:registry:) uses the importer registry")
    func renderSVGUsesImporterRegistry() throws {
        let registry = ImporterRegistry(importers: [FixtureImporter()])

        let svg = try DiagramPipeline.renderSVG(
            source: "fixture-format source",
            idPolicy: .stable,
            registry: registry
        )

        #expect(svg.contains("<svg"))
        #expect(svg.contains("Fixture"))
    }
    #endif
}

private struct FixtureImporter: DiagramSourceImporter {
    let name = "Fixture"
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart]

    func supports(source: String) -> Bool {
        true
    }

    func parse(_ source: String) throws -> DiagramImportResult {
        let document = try MermaidImporter()
            .parse("graph TD\nFixture[Fixture] --> Output[Output]")
            .document
        return DiagramImportResult(document: document)
    }
}
