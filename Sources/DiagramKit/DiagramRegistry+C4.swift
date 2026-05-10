import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _c4 = DiagramDescriptor(
        type: .c4,
        matches: { $0.raw.range(of: #"^C4(?:Context|Container|Component|Dynamic|Deployment)\s*$"#, options: .regularExpression) != nil },
        parse: { source, frontmatter in
            let c4Lines = MermaidSourceNormalizer.rawLines(source)
            let parsed = try parseC4Diagram(c4Lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .c4(parsed))
        },
        layout: { graph, _ in
            guard case let .c4(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.c4)
            }
            let positioned = layoutC4Diagram(parsed)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .c4(positioned))
        }
    )
}
