import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _kanban = DiagramDescriptor(
        type: .kanban,
        matches: { $0.normalized.hasPrefix("kanban") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            let parsed = try parseKanbanDiagram(rawLines, frontmatter: frontmatter)
            return MermaidGraph(payload: .kanban(parsed))
        },
        layout: { graph, _ in
            guard case let .kanban(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.kanban)
            }
            let positioned = layoutKanbanDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .kanban(positioned))
        }
    )
}
