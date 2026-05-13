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
    static let _requirement = _typed(
        type: .requirement,
        matches: { $0.normalized.hasPrefix("requirement") },
        parse: { source, frontmatter in
            var diagram = try parseRequirementDiagram(DiagramSourceNormalizer.diagramLines(source), frontmatter: frontmatter)
            if let theme = frontmatter?.requirementTheme {
                diagram.config.theme = theme
            }
            return diagram
        },
        wrap: DiagramPayload.requirement,
        unwrap: { payload in
            guard case let .requirement(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in try layoutRequirementDiagram(diagram) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .requirement(positioned))
        }
    )
}
