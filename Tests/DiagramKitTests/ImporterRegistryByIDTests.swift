import Testing
@testable import DiagramKit
import DiagramKitCommon
import DiagramKitImport
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitStructurizr
import DiagramKitPlantUML

@Suite struct ImporterRegistryByIDTests {

    @Test("Default registry by-ID lookup returns the matching importer")
    func defaultRegistryByID() throws {
        let registry = DiagramPipeline.defaultRegistry

        let d2 = try #require(registry.importer(for: .d2))
        #expect(d2.name == "D2")
        #expect(d2.formatID == .d2)

        let mermaid = try #require(registry.importer(for: .mermaid))
        #expect(mermaid.name == "Mermaid")
        #expect(mermaid.formatID == .mermaid)

        let plantuml = try #require(registry.importer(for: .plantuml))
        #expect(plantuml.name == "PlantUML")

        let graphviz = try #require(registry.importer(for: .graphviz))
        #expect(graphviz.name == "Graphviz")

        let structurizr = try #require(registry.importer(for: .structurizr))
        #expect(structurizr.name == "Structurizr")
    }

    @Test("Unknown formatID returns nil")
    func unknownFormatIDReturnsNil() {
        let registry = DiagramPipeline.defaultRegistry
        #expect(registry.importer(for: DiagramFormatID(rawValue: "asciiart")) == nil)
    }

    @Test("Empty registry returns nil for any formatID")
    func emptyRegistryReturnsNil() {
        let registry = ImporterRegistry.empty
        #expect(registry.importer(for: .mermaid) == nil)
        #expect(registry.importer(for: .d2) == nil)
    }

    @Test("By-ID lookup survives prepending")
    func byIDAfterPrepending() throws {
        let base = ImporterRegistry(importers: [MermaidImporter()])
        let augmented = base.prepending(D2Importer())

        let d2 = try #require(augmented.importer(for: .d2))
        #expect(d2.formatID == .d2)

        let mermaid = try #require(augmented.importer(for: .mermaid))
        #expect(mermaid.formatID == .mermaid)
    }

    @Test("By-ID lookup survives appending (broad fallback case)")
    func byIDAfterAppending() throws {
        let base = ImporterRegistry(importers: [D2Importer()])
        let augmented = base.appending(MermaidImporter())

        let d2 = try #require(augmented.importer(for: .d2))
        #expect(d2.formatID == .d2)

        let mermaid = try #require(augmented.importer(for: .mermaid))
        #expect(mermaid.formatID == .mermaid)
    }
}
