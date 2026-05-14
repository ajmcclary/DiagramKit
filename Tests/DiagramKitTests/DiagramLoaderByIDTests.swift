import Testing
@testable import DiagramKit
import DiagramKitCommon
import DiagramKitImport
import DiagramKitModel
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitStructurizr
import DiagramKitPlantUML

@Suite struct DiagramLoaderByIDTests {

    private static let mermaidSource = "graph TD\nA-->B"
    private static let d2Source = "A -> B"

    @Test("Typed parse with .mermaid returns a flowchart document")
    func parseAsMermaid() throws {
        let result = try DiagramLoader.parse(
            Self.mermaidSource,
            as: .mermaid,
            registry: DiagramPipeline.defaultRegistry
        )
        #expect(result.document.type == .flowchart)
    }

    @Test("Typed parse with .d2 returns a flowchart document on D2 source")
    func parseAsD2() throws {
        let result = try DiagramLoader.parse(
            Self.d2Source,
            as: .d2,
            registry: DiagramPipeline.defaultRegistry
        )
        #expect(result.document.type == .flowchart)
    }

    @Test("Typed parse bypasses supports(source:) probe")
    func typedParseBypassesProbe() throws {
        // The Mermaid source ("graph TD\nA-->B") would not pass the D2
        // importer's content-driven probe in normal probe-based dispatch.
        // By-ID dispatch asserts the format and feeds the source straight
        // to D2Importer.parse. The contract: the call either succeeds with
        // whatever D2 produces, or throws. It must not silently re-route.
        let registry = DiagramPipeline.defaultRegistry

        do {
            let result = try DiagramLoader.parse(
                Self.mermaidSource,
                as: .d2,
                registry: registry
            )
            _ = result
        } catch let error as DiagramError {
            // Acceptable: D2 parser may reject the Mermaid-shaped source.
            // Reject the unrelated "no importer registered" form.
            #expect(!String(describing: error).contains("no importer registered"))
        }
    }

    @Test("Unknown formatID throws unrecognizedFormat")
    func unknownFormatIDThrows() {
        let registryWithoutD2 = ImporterRegistry(importers: [MermaidImporter()])
        #expect(throws: DiagramError.self) {
            _ = try DiagramLoader.parse(
                Self.mermaidSource,
                as: .d2,
                registry: registryWithoutD2
            )
        }
    }

    @Test("Unknown formatID error message names the missing format")
    func unknownFormatIDMessage() {
        let registryWithoutD2 = ImporterRegistry(importers: [MermaidImporter()])
        do {
            _ = try DiagramLoader.parse(
                Self.mermaidSource,
                as: .d2,
                registry: registryWithoutD2
            )
            Issue.record("expected DiagramError.unrecognizedFormat")
        } catch let error as DiagramError {
            #expect(String(describing: error).contains("d2"))
        } catch {
            Issue.record("expected DiagramError, got \(error)")
        }
    }

    @Test("parseDocument(_:as:registry:) shorthand returns the same document")
    func parseDocumentShorthand() throws {
        let viaFull = try DiagramLoader.parse(
            Self.mermaidSource,
            as: .mermaid,
            registry: DiagramPipeline.defaultRegistry
        )
        let viaShorthand = try DiagramLoader.parseDocument(
            Self.mermaidSource,
            as: .mermaid,
            registry: DiagramPipeline.defaultRegistry
        )
        #expect(viaFull.document.type == viaShorthand.type)
    }
}
