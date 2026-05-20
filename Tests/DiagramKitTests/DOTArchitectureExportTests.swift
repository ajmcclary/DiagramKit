import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
@testable import DiagramKitGraphviz

@Suite("DOTArchitectureExport")
struct DOTArchitectureExportTests {

    @Test("Emits shape=cylinder for database kind")
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
        let result = try DOTArchitectureExport.emit(arch, title: nil)
        #expect(result.source.contains("db [shape=cylinder"))
        #expect(result.source.contains("api -> db"))
    }

    @Test("Cloud kind emits shape=oval + .shapeDowngrade diagnostic + marker")
    func cloudKindIsLossy() throws {
        let arch = ArchitectureDiagram(
            services: [
                ArchitectureService(id: "c1", kind: .cloud),
                ArchitectureService(id: "c2", kind: .cloud),
            ]
        )
        let result = try DOTArchitectureExport.emit(arch, title: nil)
        #expect(result.source.contains("shape=oval"))
        #expect(result.source.contains("# diagramkit:arch-icon=c1,cloud"))
        let shapeDowngrades = result.diagnostics.filter { $0.category == .shapeDowngrade }
        #expect(shapeDowngrades.count == 2)
    }

    @Test("Wraps group members in cluster_<id> subgraph")
    func groupBecomesCluster() throws {
        let arch = ArchitectureDiagram(
            groups: [ArchitectureGroup(id: "backend", title: "Backend")],
            services: [
                ArchitectureService(id: "api", parentGroupId: "backend", kind: .service),
            ]
        )
        let result = try DOTArchitectureExport.emit(arch, title: nil)
        #expect(result.source.contains("subgraph cluster_backend"))
        #expect(result.source.contains("label = \"Backend\""))
    }
}
