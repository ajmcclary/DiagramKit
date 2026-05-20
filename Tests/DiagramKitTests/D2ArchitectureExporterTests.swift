import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
@testable import DiagramKitD2

@Suite("D2ArchitectureExporter")
struct D2ArchitectureExporterTests {

    @Test("Emits shape: cylinder for database kind")
    func emitsCylinderForDatabase() throws {
        let arch = ArchitectureDiagram(
            services: [
                ArchitectureService(id: "api", kind: .service),
                ArchitectureService(id: "db", kind: .database),
            ],
            edges: [
                ArchitectureEdge(lhsId: "api", rhsId: "db",
                                 lhsDirection: .R, rhsDirection: .L,
                                 sourceArrow: false, targetArrow: true)
            ]
        )
        let result = try D2ArchitectureExport.emit(arch, title: nil)
        #expect(result.source.contains("db.shape: cylinder"))
        #expect(result.source.contains("api -> db"))
        // No marker for the database kind — it has a native D2 shape.
        #expect(!result.source.contains("diagramkit:arch-icon=db,database"))
    }

    @Test("Emits arch-icon marker for kinds without a native D2 shape")
    func emitsMarkerForNonNativeKind() throws {
        let arch = ArchitectureDiagram(
            services: [
                ArchitectureService(id: "n1", kind: .node),
                ArchitectureService(id: "n2", kind: .node),
            ]
        )
        let result = try D2ArchitectureExport.emit(arch, title: nil)
        #expect(result.source.contains("# diagramkit:arch-icon=n1,node"))
        #expect(result.source.contains("# diagramkit:arch-icon=n2,node"))
    }

    @Test("Wraps members in container for group")
    func wrapsGroupAsContainer() throws {
        let arch = ArchitectureDiagram(
            groups: [ArchitectureGroup(id: "backend", title: "Backend")],
            services: [
                ArchitectureService(id: "api", parentGroupId: "backend", kind: .service),
                ArchitectureService(id: "db", parentGroupId: "backend", kind: .database),
            ]
        )
        let result = try D2ArchitectureExport.emit(arch, title: nil)
        #expect(result.source.contains("backend"))
        #expect(result.source.contains("db.shape: cylinder"))
    }
}
