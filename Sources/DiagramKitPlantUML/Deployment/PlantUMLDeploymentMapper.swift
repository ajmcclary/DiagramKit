import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Maps a `PlantUMLDeploymentAST` to an `ArchitectureDiagram` plus
/// any diagnostics.
public struct PlantUMLDeploymentMapper {

    public init() {}

    public func map(_ ast: PlantUMLDeploymentAST) -> (ArchitectureDiagram, [DiagramDiagnostic]) {
        var groups: [ArchitectureGroup] = []
        var services: [ArchitectureService] = []
        let diagnostics: [DiagramDiagnostic] = []
        for node in ast.roots {
            visit(node, parentGroupId: nil, groups: &groups, services: &services)
        }
        var edges: [ArchitectureEdge] = []
        for astEdge in ast.edges {
            edges.append(.init(
                lhsId: astEdge.lhsId,
                rhsId: astEdge.rhsId,
                lhsDirection: .R,
                rhsDirection: .L,
                sourceArrow: astEdge.direction == .backward || astEdge.direction == .both,
                targetArrow: astEdge.direction == .forward || astEdge.direction == .both,
                lhsGroupBoundary: false,
                rhsGroupBoundary: false,
                label: astEdge.label
            ))
        }
        let diagram = ArchitectureDiagram(
            groups: groups, services: services, junctions: [], edges: edges,
            diagramTitle: ast.title
        )
        return (diagram, diagnostics)
    }

    private func visit(
        _ node: PlantUMLDeploymentAST.Node,
        parentGroupId: String?,
        groups: inout [ArchitectureGroup],
        services: inout [ArchitectureService]
    ) {
        switch node {
        case .shape(let shape):
            services.append(.init(
                id: shape.id, icon: nil, iconText: nil,
                title: shape.label, parentGroupId: parentGroupId,
                kind: shape.kind
            ))
        case .group(let group):
            groups.append(.init(
                id: group.id, icon: nil, title: group.label,
                parentGroupId: parentGroupId
            ))
            for child in group.children {
                visit(child, parentGroupId: group.id, groups: &groups, services: &services)
            }
        }
    }
}
