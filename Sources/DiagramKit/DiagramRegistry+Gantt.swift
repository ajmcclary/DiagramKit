import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _gantt = DiagramDescriptor(
        type: .gantt,
        matches: { $0.normalized.hasPrefix("gantt") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.statements(source, separators: CharacterSet(charactersIn: "\n"))
            let parsed = try parseGanttDiagram(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .gantt(parsed))
        },
        layout: { graph, _ in
            guard case let .gantt(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.gantt)
            }
            let config = parsed.config ?? .default
            var merged = parsed
            merged.config = config
            let positioned = layoutGanttDiagram(merged)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .gantt(positioned))
        }
    )
}
