import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _timeline = _typed(
        type: .timeline,
        matches: { $0.startsWithToken("timeline") },
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
