import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _block = DiagramDescriptor(
        type: .block,
        matches: { $0.normalized.hasPrefix("block") },
        parse: { source, frontmatter in
            let parsed = try parseBlockDiagram(source, frontmatter: frontmatter)
            return MermaidGraph(payload: .block(parsed))
        },
        layout: { graph, _ in
            guard case let .block(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.block)
            }
            let positioned = try layoutBlockDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .block(positioned))
        }
    )
}
