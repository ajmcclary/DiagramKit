import Foundation
import DiagramKitCommon
import DiagramKitModel

struct PlantUMLActivityMapper {

    func map(_ ast: PlantUMLActivityAST) -> (ParsedGraphModel, [DiagramDiagnostic]) {
        let diagnostics: [DiagramDiagnostic] = []
        var nodesInOrder: [(id: String, node: original_src_types.MermaidNode)] = []
        var edges: [original_src_types.MermaidEdge] = []

        for node in ast.nodes {
            let mermaidNode = original_src_types.MermaidNode(
                id: node.id,
                label: node.label,
                shape: shape(for: node.shape)
            )
            nodesInOrder.append((id: node.id, node: mermaidNode))
        }

        for edge in ast.edges {
            edges.append(original_src_types.MermaidEdge(
                source: edge.source,
                target: edge.target,
                label: edge.label,
                style: .solid
            ))
        }

        // PlantUML `partition "Name" { … }` blocks surface as flowchart
        // subgraphs. Member node ids were collected by the parser; the
        // subgraph's label is the partition's display label. The
        // activity-partition recovery marker (Wave C 2026-05-20) still
        // round-trips the `partition` keyword on export.
        var subgraphs: [original_src_types.MermaidSubgraph] = []
        for partition in ast.partitions {
            subgraphs.append(original_src_types.MermaidSubgraph(
                id: partition.id,
                label: partition.label,
                nodeIds: partition.memberNodeIDs
            ))
        }

        let graph = ParsedGraphModel(
            direction: .TB,
            nodesInOrder: nodesInOrder,
            edges: edges,
            subgraphs: subgraphs
        )

        return (graph, diagnostics)
    }

    private func shape(for s: PlantUMLActivityAST.Node.NodeShape) -> original_src_types.NodeShape {
        switch s {
        case .startTerminator, .stopTerminator: return .stadium
        case .action: return .rectangle
        case .decision: return .diamond
        }
    }
}
