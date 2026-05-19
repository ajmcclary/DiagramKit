import Foundation
import DiagramKitCommon
import DiagramKitModel

struct PlantUMLActivityMapper {

    func map(_ ast: PlantUMLActivityAST) -> (ParsedGraphModel, [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
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

        let graph = ParsedGraphModel(
            direction: .TB,
            nodesInOrder: nodesInOrder,
            edges: edges
        )

        for partition in ast.partitions {
            diagnostics.append(.lossyTransform(
                .subgraphFlatten,
                message: "PlantUML partition '\(partition.label)' flattened into flowchart payload; swimlane structure lost (members: \(partition.memberNodeIDs.joined(separator: ", ")))"
            ))
        }

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
