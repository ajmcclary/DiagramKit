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
    static let _journey = DiagramDescriptor(
        type: .journey,
        matches: { $0.normalized.hasPrefix("journey") },
        parse: { source, frontmatter in
            let lines = DiagramSourceNormalizer.statements(source)
            let parsed = try parseJourneyDiagram(lines, frontmatter: frontmatter)
            return DiagramDocument(payload: .journey(parsed))
        },
        layout: { graph, _ in
            guard case let .journey(parsed) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.journey)
            }
            let config = parsed.config ?? .default
            let positioned = layoutJourneyDiagram(parsed, options: RenderOptions(), config: config)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .journey(positioned))
        }
    )
}
