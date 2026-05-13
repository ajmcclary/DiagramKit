import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// These descriptors are Mermaid-specific. A format-agnostic importer registry
// (ImporterRegistry + DiagramSourceImporter) will be introduced in Phase 1.
// At that point this type will become MermaidDiagramRegistry or be subsumed
// into MermaidImporter.
extension DiagramRegistry {
    static let _kanban = _typed(
        type: .kanban,
        matches: { $0.normalized.hasPrefix("kanban") },
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
