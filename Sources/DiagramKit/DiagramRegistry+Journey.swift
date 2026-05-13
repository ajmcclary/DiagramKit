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
    static let _journey = _typed(
        type: .journey,
        matches: { $0.normalized.hasPrefix("journey") },
        parse: { source, frontmatter in
            try parseJourneyDiagram(DiagramSourceNormalizer.statements(source), frontmatter: frontmatter)
        },
        wrap: DiagramPayload.journey,
        unwrap: { payload in
            guard case let .journey(value) = payload else { return nil }
            return value
        },
        layout: { parsed, _ in
            layoutJourneyDiagram(parsed, options: RenderOptions(), config: parsed.config ?? .default)
        },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .journey(positioned))
        }
    )
}
