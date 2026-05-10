import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _sankey = DiagramDescriptor(
        type: .sankey,
        matches: { $0.normalized.hasPrefix("sankey") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.statements(source)
            let parsed = try parseSankeyDiagram(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .sankey(parsed))
        },
        layout: { graph, _ in
            guard case let .sankey(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.sankey)
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
