import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// These descriptors are Mermaid-specific. A format-agnostic importer registry
// (ImporterRegistry + DiagramSourceImporter) will be introduced in Phase 1.
// At that point this type will become DiagramViewModelRegistry or be subsumed
// into MermaidImporter.
extension DiagramRegistry {
    static let _timeline = DiagramDescriptor(
        type: .timeline,
        matches: { $0.normalized.hasPrefix("timeline") },
        parse: { source, frontmatter in
            let rawLines = DiagramSourceNormalizer.rawLines(source)
            let parsed = try parseTimelineDiagram(rawLines, frontmatter: frontmatter)
            return DiagramDocument(payload: .timeline(parsed))
        },
        layout: { graph, _ in
            guard case let .timeline(diagram) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.timeline)
            }
            let positioned = layoutTimelineDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .timeline(positioned))
        }
    )
}
