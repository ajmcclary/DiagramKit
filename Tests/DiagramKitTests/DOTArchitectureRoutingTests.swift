import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
@testable import DiagramKitGraphviz

@Suite("DOT architecture routing")
struct DOTArchitectureRoutingTests {

    @Test("Importer routes shape-heavy DOT source to architecture payload")
    func importerRoutesArchitecture() throws {
        let source = """
        digraph G {
          api [shape=box];
          db [shape=cylinder];
          cache [shape=cylinder];
          api -> db;
          api -> cache;
        }
        """
        let result = try GraphvizImporter().parse(source)
        guard case .architecture = result.document.payload else {
            Issue.record("expected architecture payload, got \(result.document.payload)")
            return
        }
    }

    @Test("Importer routes family marker even without two native shapes")
    func markerForcesArchitecture() throws {
        let source = """
        digraph G {
          # diagramkit:family=architecture
          a -> b;
        }
        """
        let result = try GraphvizImporter().parse(source)
        guard case .architecture = result.document.payload else {
            Issue.record("expected architecture payload, got \(result.document.payload)")
            return
        }
    }

    @Test("Exporter dispatches architecture payload to DOTArchitectureExport")
    func exporterDispatchesArchitecture() throws {
        let arch = ArchitectureDiagram(
            services: [
                ArchitectureService(id: "api", kind: .service),
                ArchitectureService(id: "db", kind: .database),
            ]
        )
        let document = DiagramDocument(payload: .architecture(arch))
        let result = try DOTExporter().export(document)
        #expect(result.source.contains("shape=cylinder"))
    }
}
