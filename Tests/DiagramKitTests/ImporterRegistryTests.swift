import Testing
@testable import DiagramKit
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitStructurizr
import DiagramKitPlantUML

@Suite struct ImporterRegistryTests {

    @Test("Default registry has Structurizr first, PlantUML second, Graphviz third, D2 fourth, Mermaid last")
    func defaultRegistryOrder() throws {
        let registry = DiagramPipeline.defaultRegistry
        #expect(registry.importers.count >= 5)
        #expect(registry.importers[0].name == "Structurizr")
        #expect(registry.importers[1].name == "PlantUML")
        #expect(registry.importers[2].name == "Graphviz")
        #expect(registry.importers[3].name == "D2")
        #expect(registry.importers.last?.name == "Mermaid")

        // Structurizr-shaped source picks Structurizr
        let structurizrImporter = try #require(registry.importer(for: "workspace { model { } views { } }"))
        #expect(structurizrImporter.name == "Structurizr")

        // PlantUML-shaped source picks PlantUML
        let plantUMLImporter = try #require(registry.importer(for: "@startuml\nAlice -> Bob: Hello\n@enduml"))
        #expect(plantUMLImporter.name == "PlantUML")

        // DOT-shaped source picks Graphviz
        let dotImporter = try #require(registry.importer(for: "digraph G { A -> B }"))
        #expect(dotImporter.name == "Graphviz")

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

        // Graphviz prepended before D2+Mermaid
        let dot = GraphvizImporter()
        let withDot = extended.prepending(dot)
        #expect(withDot.importers.count == 3)
        #expect(withDot.importers[0].name == "Graphviz")
        #expect(withDot.importers[1].name == "D2")
        #expect(withDot.importers[2].name == "Mermaid")

        // Structurizr prepended before Graphviz+D2+Mermaid
        let structurizr = StructurizrImporter()
        let withStructurizr = withDot.prepending(structurizr)
        #expect(withStructurizr.importers.count == 4)
        #expect(withStructurizr.importers[0].name == "Structurizr")
        #expect(withStructurizr.importers[1].name == "Graphviz")
        #expect(withStructurizr.importers[2].name == "D2")
        #expect(withStructurizr.importers[3].name == "Mermaid")
    }

    @Test("Fallback contract: only Mermaid declares isFallback in the default registry")
    func fallbackContractDefaultRegistry() {
        let registry = DiagramPipeline.defaultRegistry
        let fallbacks = registry.importers.filter(\.isFallback)
        #expect(fallbacks.count == 1)
        #expect(fallbacks.first?.name == "Mermaid")
        #expect(registry.importers.last?.isFallback == true)
        // Every non-Mermaid importer must declare isFallback = false.
        for importer in registry.importers.dropLast() {
            #expect(importer.isFallback == false, "Importer '\(importer.name)' must not declare isFallback = true (only the last importer may).")
        }
    }

    @Test("Fallback contract: empty and narrow-only registries pass the precondition")
    func fallbackContractAllowsNoFallback() {
        // Empty registry — allowed.
        _ = ImporterRegistry.empty
        // Single narrow importer, no fallback — allowed.
        _ = ImporterRegistry(importers: [D2Importer()])
        // Multiple narrow importers, no fallback — allowed.
        _ = ImporterRegistry(importers: [StructurizrImporter(), D2Importer()])
    }

    @Test("Fallback contract: prepending/appending preserve the invariant on known-good shapes")
    func fallbackContractCombinatorsRespectInvariant() {
        let base = ImporterRegistry(importers: [MermaidImporter()])
        // prepending a narrow importer keeps Mermaid last — allowed.
        let prepended = base.prepending(D2Importer())
        #expect(prepended.importers.last?.name == "Mermaid")
        // appending a narrow importer onto an empty registry — allowed.
        let appended = ImporterRegistry.empty.appending(D2Importer())
        #expect(appended.importers.count == 1)
        #expect(appended.importers[0].isFallback == false)
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
    let formatID = DiagramFormatID(rawValue: "fixture")
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
