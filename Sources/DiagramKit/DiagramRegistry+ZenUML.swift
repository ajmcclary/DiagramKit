import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _zenuml = DiagramDescriptor(
        type: .zenuml,
        matches: { $0.normalized.hasPrefix("zenuml") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            var parsed = try parseZenUMLDiagram(rawLines, frontmatter: frontmatter)
            parsed.useMaxWidth = frontmatter?.sequenceConfig?.useMaxWidth ?? true
            return MermaidGraph(payload: .zenuml(parsed))
        },
        layout: { graph, _ in
            guard case let .zenuml(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.zenuml)
            }
            let positioned = layoutZenUMLDiagram(parsed, useMaxWidth: parsed.useMaxWidth)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .zenuml(positioned))
        }
    )
}
