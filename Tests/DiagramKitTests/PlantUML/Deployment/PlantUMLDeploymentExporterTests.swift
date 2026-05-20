import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
@testable import DiagramKitPlantUML

@Suite("PlantUMLDeploymentExporterTests")
struct PlantUMLDeploymentExporterTests {

    @Test func dispatcherRoutesDeploymentKindToDeploymentExporter() throws {
        let diagram = ArchitectureDiagram(
            groups: [],
            services: [
                .init(id: "db", title: "Postgres", parentGroupId: nil, kind: .database)
            ]
        )
        let document = DiagramDocument(payload: .architecture(diagram))
        let exporter = PlantUMLExporter()
        let result = try exporter.export(document)
        #expect(result.source.contains("database"))
        #expect(!result.source.contains("[db]"))
    }

    @Test func dispatcherRoutesComponentOnlyKindsToComponentExporter() throws {
        let diagram = ArchitectureDiagram(
            services: [
                .init(id: "web", title: "Web", parentGroupId: nil, kind: .component),
                .init(id: "http", title: nil, parentGroupId: nil, kind: .interface)
            ]
        )
        let document = DiagramDocument(payload: .architecture(diagram))
        let result = try PlantUMLExporter().export(document)
        #expect(result.source.contains("[web]"))
        #expect(!result.source.contains("database"))
    }

    @Test func dispatcherRoutesPureServiceKindToComponentExporter() throws {
        let diagram = ArchitectureDiagram(
            services: [.init(id: "x", title: "X", parentGroupId: nil, kind: .service)]
        )
        let document = DiagramDocument(payload: .architecture(diagram))
        let result = try PlantUMLExporter().export(document)
        #expect(result.source.contains("[x]"))
    }

    @Test func emitsBareShape() throws {
        let diagram = ArchitectureDiagram(
            services: [.init(id: "db", title: "Postgres", parentGroupId: nil, kind: .database)]
        )
        let result = try PlantUMLDeploymentExport.emit(diagram)
        #expect(result.source.contains(#"database "Postgres" as db"#))
        #expect(result.source.hasPrefix("@startuml"))
        #expect(result.source.contains("@enduml"))
    }

    @Test func emitsNestedGroup() throws {
        let diagram = ArchitectureDiagram(
            groups: [.init(id: "aws", title: "AWS", parentGroupId: nil)],
            services: [.init(id: "ec2", title: "EC2", parentGroupId: "aws", kind: .node)]
        )
        let result = try PlantUMLDeploymentExport.emit(diagram)
        #expect(result.source.contains(#"node "EC2" as ec2"#))
        #expect(result.source.contains("aws {"))
        #expect(result.source.contains("}"))
    }

    @Test func emitsEdgeWithLabel() throws {
        let diagram = ArchitectureDiagram(
            services: [
                .init(id: "a", title: nil, parentGroupId: nil, kind: .node),
                .init(id: "b", title: nil, parentGroupId: nil, kind: .node)
            ],
            edges: [.init(lhsId: "a", rhsId: "b", lhsDirection: .R, rhsDirection: .L,
                          sourceArrow: false, targetArrow: true, label: "writes")]
        )
        let result = try PlantUMLDeploymentExport.emit(diagram)
        #expect(result.source.contains("a --> b : writes"))
    }

    @Test func componentExportFlagsDeploymentKindAsShapeDowngrade() throws {
        let diagram = ArchitectureDiagram(
            services: [.init(id: "db", title: "Postgres", parentGroupId: nil, kind: .database)]
        )
        let result = try PlantUMLComponentExport.emit(diagram)
        #expect(result.source.contains("[db]"))
        let downgrades = result.diagnostics.filter { $0.category == .shapeDowngrade }
        #expect(downgrades.count == 1)
    }

    @Test func roundTripsThroughImporter() throws {
        let source = #"""
        @startuml
        cloud "AWS" as aws {
          node "EC2" as ec2
        }
        database "Postgres" as db
        ec2 --> db : writes
        @enduml
        """#
        let parsed = try PlantUMLImporter().parse(source)
        guard case .architecture(let arch) = parsed.document.payload else {
            Issue.record("not architecture"); return
        }
        let exported = try PlantUMLDeploymentExport.emit(arch)
        let reparsed = try PlantUMLImporter().parse(exported.source)
        guard case .architecture(let arch2) = reparsed.document.payload else {
            Issue.record("not architecture after round-trip"); return
        }
        #expect(Set(arch2.services.map(\.id)) == Set(arch.services.map(\.id)))
        #expect(Set(arch2.groups.map(\.id)) == Set(arch.groups.map(\.id)))
        #expect(arch2.edges.count == arch.edges.count)
    }
}
