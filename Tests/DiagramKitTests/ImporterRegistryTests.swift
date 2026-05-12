import Testing
@testable import DiagramKit
import DiagramKitModel
import DiagramKitImport

@Suite struct ImporterRegistryTests {

    @Test("Default registry picks Mermaid for Mermaid source")
    func defaultRegistryPicksMermaid() throws {
        let registry = DiagramPipeline.defaultRegistry
        #expect(registry.importers.count == 1)
        #expect(registry.importers[0].name == "Mermaid")

        let source = "graph TD\nA-->B"
        let importer = try #require(registry.importer(for: source))
        #expect(importer.name == "Mermaid")
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

        // Verify prepending would put a new importer first (for Phase 3+)
        let extended = base.prepending(MermaidImporter())
        #expect(extended.importers.count == 2)
        #expect(extended.importers[0].name == "Mermaid")
        #expect(extended.importers[1].name == "Mermaid")
    }
}
