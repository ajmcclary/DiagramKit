import Testing
import DiagramKitModel
@testable import DiagramKitPlantUML

@Suite("Stale ⚠ cells emit no diagnostics on supported input")
struct StaleCellsDiagnosticFreeTests {

    @Test("PlantUMLClassExport emits zero diagnostics on a simple class diagram")
    func plantUMLClassExportClean() throws {
        let order = ClassNode(
            id: "Order",
            label: "Order",
            attributes: [
                ClassMember(id: "id", visibility: "+", memberType: .attribute, returnType: "String")
            ],
            methods: [
                ClassMember(id: "place", visibility: "+", memberType: .method, returnType: "Bool")
            ]
        )
        let payload = ClassDiagram(
            classes: [order],
            classMap: ["Order": order],
            relationships: []
        )
        let result = try PlantUMLClassExport.emit(payload)
        #expect(result.diagnostics.isEmpty,
                "PlantUMLClassExport should emit no diagnostics; got: \(result.diagnostics)")
    }

    @Test("PlantUMLComponentExport emits zero diagnostics on a simple architecture diagram")
    func plantUMLComponentExportClean() throws {
        let payload = ArchitectureDiagram(
            services: [
                ArchitectureService(id: "auth", title: "Auth Service"),
                ArchitectureService(id: "db", title: "Database"),
            ],
            edges: [
                ArchitectureEdge(
                    lhsId: "auth",
                    rhsId: "db",
                    lhsDirection: .R,
                    rhsDirection: .L,
                    sourceArrow: false,
                    targetArrow: true,
                    label: ""
                )
            ],
            diagramTitle: "Test"
        )
        let result = try PlantUMLComponentExport.emit(payload)
        #expect(result.diagnostics.isEmpty,
                "PlantUMLComponentExport should emit no diagnostics; got: \(result.diagnostics)")
    }
}
