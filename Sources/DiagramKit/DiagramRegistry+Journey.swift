import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _journey = DiagramDescriptor(
        type: .journey,
        matches: { $0.normalized.hasPrefix("journey") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.statements(source)
            let parsed = try parseJourneyDiagram(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .journey(parsed))
        },
        layout: { graph, _ in
            guard case let .journey(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.journey)
            }
            let config = parsed.config ?? .default
            let positioned = layoutJourneyDiagram(parsed, options: RenderOptions(), config: config)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .journey(positioned))
        }
    )
}
