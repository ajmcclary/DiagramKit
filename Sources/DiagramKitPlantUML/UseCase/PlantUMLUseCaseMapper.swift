import Foundation
import DiagramKitCommon
import DiagramKitModel

struct PlantUMLUseCaseMapper {

    func map(_ ast: PlantUMLUseCaseAST) -> (ParsedGraphModel, [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var nodesInOrder: [(id: String, node: original_src_types.MermaidNode)] = []
        var edges: [original_src_types.MermaidEdge] = []

        for node in ast.nodes {
            let mermaidNode = original_src_types.MermaidNode(
                id: node.id,
                label: node.display,
                shape: .stadium
            )
            nodesInOrder.append((id: node.id, node: mermaidNode))
            if node.kind == .actor {
                diagnostics.append(.lossyTransform(
                    .styleDrop,
                    message: "PlantUML actor styling for '\(node.display)' projected as use-case node when mapping to flowchart payload"
                ))
            }
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
        return (graph, diagnostics)
    }
}
