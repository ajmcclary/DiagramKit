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
    static let _gitGraph = _typed(
        type: .gitGraph,
        matches: { $0.normalized.hasPrefix("gitgraph") },
        parse: { source, frontmatter in
            try parseGitGraph(DiagramSourceNormalizer.statements(source), frontmatter: frontmatter)
        },
        wrap: DiagramPayload.gitGraph,
        unwrap: { payload in
            guard case let .gitGraph(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in layoutGitGraph(diagram) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .gitGraph(positioned))
        }
    )
}
