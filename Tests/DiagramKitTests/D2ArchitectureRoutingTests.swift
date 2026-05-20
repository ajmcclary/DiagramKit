import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
@testable import DiagramKitD2

@Suite("D2 architecture routing")
struct D2ArchitectureRoutingTests {

    @Test("Importer routes shape-heavy source to architecture payload")
    func importerRoutesArchitecture() throws {
        let source = """
        api.shape: rectangle
        db.shape: cylinder
        cache.shape: cylinder
        api -> db
        api -> cache
        """
        let result = try D2Importer().parse(source)
        guard case .architecture = result.document.payload else {
            Issue.record("expected architecture payload, got \(result.document.payload)")
            return
        }
    }

    @Test("Importer routes family marker even without two native shapes")
    func markerForcesArchitecture() throws {
        let source = """
        # diagramkit:family=architecture
        a -> b
        """
        let result = try D2Importer().parse(source)
        guard case .architecture = result.document.payload else {
            Issue.record("expected architecture payload, got \(result.document.payload)")
            return
        }
    }

    @Test("Exporter dispatches architecture payload to D2ArchitectureExport")
    func exporterDispatchesArchitecture() throws {
        let arch = ArchitectureDiagram(
            services: [
                ArchitectureService(id: "api", kind: .service),
                ArchitectureService(id: "db", kind: .database),
            ]
        )
        let document = DiagramDocument(payload: .architecture(arch))
        let result = try D2Exporter().export(document)
        #expect(result.source.contains("db.shape: cylinder"))
    }
}
