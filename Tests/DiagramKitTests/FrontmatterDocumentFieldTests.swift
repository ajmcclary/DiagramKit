// Visual editor plan 6 — frontmatter theme/layout round-trip through
// the document model, importer, and exporter.

import Testing
import DiagramKitModel
import DiagramKitMermaid
@testable import DiagramKit

@Suite
struct FrontmatterDocumentFieldTests {

    // The frontmatter parser binds config.theme / config.layout
    // (nested under `config:`), matching mermaid-js v11 frontmatter.
    private let themedSource = """
    ---
    title: Themed
    config:
      theme: nord
      layout: adaptive
    ---
    graph TD
      A --> B
    """

    @Test("importer lifts shared theme/layout onto the document")
    func importerLift() throws {
        let doc = try MermaidImporter().parse(themedSource).document
        #expect(doc.frontmatter?.theme == "nord")
        #expect(doc.frontmatter?.layout == "adaptive")
        #expect(doc.title == "Themed")
    }

    @Test("exporter emits theme/layout in the frontmatter block")
    func exporterEmit() throws {
        var doc = try MermaidImporter().parse("graph TD\n  A --> B\n").document
        doc.frontmatter = DiagramDocumentFrontmatter(theme: "nord", layout: "adaptive")
        let result = try MermaidExporter().export(doc)
        #expect(result.source.hasPrefix("---\n"))
        #expect(result.source.contains("theme: nord"))
        #expect(result.source.contains("layout: adaptive"))
    }

    @Test("theme/layout survive parse → export → parse")
    func roundTrip() throws {
        let doc = try MermaidImporter().parse(themedSource).document
        let exported = try MermaidExporter().export(doc).source
        let reparsed = try MermaidImporter().parse(exported).document
        #expect(reparsed.frontmatter?.theme == "nord")
        #expect(reparsed.frontmatter?.layout == "adaptive")
        #expect(reparsed.title == "Themed")
    }

    @Test("no frontmatter → nil slot and no emitted block")
    func absentFrontmatter() throws {
        let doc = try MermaidImporter().parse("graph TD\n  A --> B\n").document
        #expect(doc.frontmatter == nil || doc.frontmatter?.isEmpty == true)
        let exported = try MermaidExporter().export(doc).source
        #expect(!exported.hasPrefix("---"))
    }

    @Test("theme-only frontmatter emits without a title")
    func themeWithoutTitle() throws {
        var doc = try MermaidImporter().parse("graph TD\n  A --> B\n").document
        doc.frontmatter = DiagramDocumentFrontmatter(theme: "dracula")
        let exported = try MermaidExporter().export(doc).source
        #expect(exported.hasPrefix("---\n"))
        #expect(exported.contains("theme: dracula"))
        let reparsed = try MermaidImporter().parse(exported).document
        #expect(reparsed.frontmatter?.theme == "dracula")
    }
}
