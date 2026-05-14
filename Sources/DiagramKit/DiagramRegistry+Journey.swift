import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _journey = _typed(
        type: .journey,
        matches: { $0.startsWithToken("journey") },
        parseWithDiagnostics: { source, frontmatter in
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
