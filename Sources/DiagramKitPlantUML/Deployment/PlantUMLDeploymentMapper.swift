import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Maps a `PlantUMLDeploymentAST` to an `ArchitectureDiagram` plus
/// any diagnostics. Also accumulates decoration metadata (group kind,
/// stereotypes, colors, notes, legend, edge style/stereotype) as
/// comment-encoded recovery-marker strings stored on
/// `ArchitectureDiagram.recoveryMarkers` for the exporter to re-emit.
public struct PlantUMLDeploymentMapper {

    public init() {}

    public func map(_ ast: PlantUMLDeploymentAST) -> (ArchitectureDiagram, [DiagramDiagnostic]) {
        var groups: [ArchitectureGroup] = []
        var services: [ArchitectureService] = []
        var markers: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        for node in ast.roots {
            visit(node, parentGroupId: nil, groups: &groups, services: &services, markers: &markers)
        }

        var edges: [ArchitectureEdge] = []
        for (index, astEdge) in ast.edges.enumerated() {
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
            if astEdge.style == .dashed {
                markers.append(PlantUMLRecoveryMarker.emitDeploymentEdgeStyle(
                    edgeIndex: index, style: "dashed"))
            }
            if let stereotype = astEdge.stereotype {
                markers.append(PlantUMLRecoveryMarker.emitDeploymentEdgeStereotype(
                    edgeIndex: index, stereotype: stereotype))
            }
        }

        for note in ast.notes {
            markers.append(PlantUMLRecoveryMarker.emitDeploymentNote(
                serviceId: note.serviceId, position: note.position, body: note.body))
        }
        if let legend = ast.legend {
            markers.append(PlantUMLRecoveryMarker.emitDeploymentLegend(body: legend))
        }

        let diagram = ArchitectureDiagram(
            groups: groups, services: services, junctions: [], edges: edges,
            diagramTitle: ast.title, recoveryMarkers: markers
        )
        return (diagram, diagnostics)
    }

    private func visit(
        _ node: PlantUMLDeploymentAST.Node,
        parentGroupId: String?,
        groups: inout [ArchitectureGroup],
        services: inout [ArchitectureService],
        markers: inout [String]
    ) {
        switch node {
        case .shape(let shape):
            services.append(.init(
                id: shape.id, icon: nil, iconText: nil,
                title: shape.label, parentGroupId: parentGroupId,
                kind: shape.kind
            ))
            if let stereotype = shape.stereotype {
                markers.append(PlantUMLRecoveryMarker.emitDeploymentServiceStereotype(
                    serviceId: shape.id, stereotype: stereotype))
            }
            if let color = shape.color {
                markers.append(PlantUMLRecoveryMarker.emitDeploymentServiceColor(
                    serviceId: shape.id, color: color))
            }
        case .group(let group):
            groups.append(.init(
                id: group.id, icon: nil, title: group.label,
                parentGroupId: parentGroupId
            ))
            // Always record the original group kind — even .node, so the
            // exporter doesn't have to guess on round-trip.
            markers.append(PlantUMLRecoveryMarker.emitDeploymentGroupKind(
                groupId: group.id, kindRawValue: group.kind.rawValue))
            if let stereotype = group.stereotype {
                markers.append(PlantUMLRecoveryMarker.emitDeploymentGroupStereotype(
                    groupId: group.id, stereotype: stereotype))
            }
            if let color = group.color {
                markers.append(PlantUMLRecoveryMarker.emitDeploymentGroupColor(
                    groupId: group.id, color: color))
            }
            for child in group.children {
                visit(child, parentGroupId: group.id,
                      groups: &groups, services: &services, markers: &markers)
            }
        }
    }
}
