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
    static let _timeline = _typed(
        type: .timeline,
        matches: { $0.normalized.hasPrefix("timeline") },
        parse: { source, frontmatter in
            try parseTimelineDiagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
        },
        wrap: DiagramPayload.timeline,
        unwrap: { payload in
            guard case let .timeline(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in layoutTimelineDiagram(diagram) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .timeline(positioned))
        }
    )
}
