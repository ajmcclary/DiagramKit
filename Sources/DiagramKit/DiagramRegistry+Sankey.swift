import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _sankey = _typed(
        type: .sankey,
        matches: { $0.startsWithToken("sankey") },
        parse: { source, frontmatter in
            try parseSankeyDiagram(DiagramSourceNormalizer.statements(source), frontmatter: frontmatter)
        },
        wrap: DiagramPayload.sankey,
        unwrap: { payload in
            guard case let .sankey(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in layoutSankeyDiagram(diagram) },
        positioned: { graph, positioned in
            let padding = positioned.config.useMaxWidth ? 0.0 : 10.0
            return PositionedGraph(
                diagram: graph,
                width: positioned.width + padding * 2,
                height: positioned.height + padding * 2,
                content: .sankey(positioned)
            )
        }
    )
}
