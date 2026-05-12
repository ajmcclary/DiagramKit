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
    static let _requirement = DiagramDescriptor(
        type: .requirement,
        matches: { $0.normalized.hasPrefix("requirement") },
        parse: { source, frontmatter in
            let lines = DiagramSourceNormalizer.diagramLines(source)
            var diagram = try parseRequirementDiagram(lines, frontmatter: frontmatter)
            if let theme = frontmatter?.requirementTheme {
                diagram.config.theme = theme
            }
            return DiagramDocument(payload: .requirement(diagram))
        },
        layout: { graph, _ in
            guard case let .requirement(diagram) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.requirement)
            }
            let positioned = try layoutRequirementDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .requirement(positioned))
        }
    )
}
