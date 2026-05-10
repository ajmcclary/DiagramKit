import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _gitGraph = DiagramDescriptor(
        type: .gitGraph,
        matches: { $0.normalized.hasPrefix("gitgraph") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.statements(source)
            let parsed = try parseGitGraph(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .gitGraph(parsed))
        },
        layout: { graph, _ in
            guard case let .gitGraph(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.gitGraph)
            }
            let positioned = layoutGitGraph(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .gitGraph(positioned))
        }
    )
}
