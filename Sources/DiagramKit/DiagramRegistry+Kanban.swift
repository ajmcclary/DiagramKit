import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _kanban = _typed(
        type: .kanban,
        matches: { $0.startsWithToken("kanban") },
        parse: { source, frontmatter in
            try parseKanbanDiagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
        },
        wrap: DiagramPayload.kanban,
        unwrap: { payload in
            guard case let .kanban(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in layoutKanbanDiagram(diagram) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .kanban(positioned))
        }
    )
}
