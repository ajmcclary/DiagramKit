import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
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
