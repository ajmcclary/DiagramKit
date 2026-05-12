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
    static let _gitGraph = DiagramDescriptor(
        type: .gitGraph,
        matches: { $0.normalized.hasPrefix("gitgraph") },
        parse: { source, frontmatter in
            let lines = DiagramSourceNormalizer.statements(source)
            let parsed = try parseGitGraph(lines, frontmatter: frontmatter)
            return DiagramDocument(payload: .gitGraph(parsed))
        },
        layout: { graph, _ in
            guard case let .gitGraph(diagram) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.gitGraph)
            }
            let positioned = layoutGitGraph(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .gitGraph(positioned))
        }
    )
}
