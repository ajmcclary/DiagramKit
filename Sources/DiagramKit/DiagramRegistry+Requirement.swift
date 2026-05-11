import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _requirement = DiagramDescriptor(
        type: .requirement,
        matches: { $0.normalized.hasPrefix("requirement") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.diagramLines(source)
            var diagram = try parseRequirementDiagram(lines, frontmatter: frontmatter)
            if let theme = frontmatter?.requirementTheme {
                diagram.config.theme = theme
            }
            return MermaidGraph(payload: .requirement(diagram))
        },
        layout: { graph, _ in
            guard case let .requirement(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.requirement)
            }
            let positioned = try layoutRequirementDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .requirement(positioned))
        }
    )
}
