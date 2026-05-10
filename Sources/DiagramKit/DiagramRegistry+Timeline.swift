import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _timeline = DiagramDescriptor(
        type: .timeline,
        matches: { $0.normalized.hasPrefix("timeline") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            let parsed = try parseTimelineDiagram(rawLines, frontmatter: frontmatter)
            return MermaidGraph(payload: .timeline(parsed))
        },
        layout: { graph, _ in
            guard case let .timeline(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.timeline)
            }
            let positioned = layoutTimelineDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .timeline(positioned))
        }
    )
}
