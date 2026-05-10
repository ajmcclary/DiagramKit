import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _packet = DiagramDescriptor(
        type: .packet,
        matches: { $0.normalized.hasPrefix("packet") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.statements(source)
            let parsed = try parsePacketDiagram(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .packet(parsed))
        },
        layout: { graph, _ in
            guard case let .packet(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.packet)
            }
            let positioned = layoutPacketDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .packet(positioned))
        }
    )
}
