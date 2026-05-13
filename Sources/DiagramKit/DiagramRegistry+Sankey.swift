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
    static let _sankey = _typed(
        type: .sankey,
        matches: { $0.normalized.hasPrefix("sankey") },
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
