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
    static let _sankey = DiagramDescriptor(
        type: .sankey,
        matches: { $0.normalized.hasPrefix("sankey") },
        parse: { source, frontmatter in
            let lines = DiagramSourceNormalizer.statements(source)
            let parsed = try parseSankeyDiagram(lines, frontmatter: frontmatter)
            return DiagramDocument(payload: .sankey(parsed))
        },
        layout: { graph, _ in
            guard case let .sankey(diagram) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.sankey)
            }
            let positioned = layoutSankeyDiagram(diagram)
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
