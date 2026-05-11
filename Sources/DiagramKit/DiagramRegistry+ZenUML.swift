import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _zenuml = DiagramDescriptor(
        type: .zenuml,
        matches: { $0.normalized.hasPrefix("zenuml") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            let parsed = try parseZenUMLDiagram(rawLines, frontmatter: frontmatter)
            return MermaidGraph(payload: .zenuml(parsed))
        },
        layout: { graph, _ in
            guard case let .zenuml(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.zenuml)
            }
            let positioned = layoutZenUMLDiagram(parsed, useMaxWidth: true)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .zenuml(positioned))
        }
    )
}
