import Foundation
import DiagramKitCommon
import DiagramKitModel

struct PlantUMLComponentMapper {

    func map(_ ast: PlantUMLComponentAST) -> (ArchitectureDiagram, [DiagramDiagnostic]) {
        let diagnostics: [DiagramDiagnostic] = []
        var services: [ArchitectureService] = []
        for component in ast.components {
            let kind: ArchitectureServiceKind
            switch component.kind {
            case .component: kind = .component
            case .interface: kind = .interface
            }
            services.append(ArchitectureService(
                id: component.id,
                title: component.label,
                kind: kind
            ))
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
