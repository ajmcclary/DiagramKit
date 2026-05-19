import Foundation
import DiagramKitCommon
import DiagramKitModel

struct PlantUMLComponentMapper {

    func map(_ ast: PlantUMLComponentAST) -> (ArchitectureDiagram, [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var services: [ArchitectureService] = []
        for component in ast.components {
            services.append(ArchitectureService(
                id: component.id,
                title: component.label
            ))
            if component.kind == .interface {
                diagnostics.append(.lossyTransform(
                    .styleDrop,
                    message: "PlantUML interface '\(component.id)' projected as architecture service; interface-vs-component styling lost"
                ))
            }
        }

        var edges: [ArchitectureEdge] = []
        for edge in ast.edges {
            edges.append(ArchitectureEdge(
                lhsId: edge.source,
                rhsId: edge.target,
                lhsDirection: .R,
                rhsDirection: .L,
                sourceArrow: false,
                targetArrow: true,
                label: edge.label
            ))
        }

        let diagram = ArchitectureDiagram(
            services: services,
            edges: edges,
            diagramTitle: ast.title
        )
        return (diagram, diagnostics)
    }
}
