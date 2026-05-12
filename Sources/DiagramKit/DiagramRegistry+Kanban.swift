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
    static let _kanban = DiagramDescriptor(
        type: .kanban,
        matches: { $0.normalized.hasPrefix("kanban") },
        parse: { source, frontmatter in
            let rawLines = DiagramSourceNormalizer.rawLines(source)
            let parsed = try parseKanbanDiagram(rawLines, frontmatter: frontmatter)
            return DiagramDocument(payload: .kanban(parsed))
        },
        layout: { graph, _ in
            guard case let .kanban(diagram) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.kanban)
            }
            let positioned = layoutKanbanDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .kanban(positioned))
        }
    )
}
