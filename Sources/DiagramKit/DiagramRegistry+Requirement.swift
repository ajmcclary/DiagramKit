import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _requirement = _typed(
        type: .requirement,
        matches: { $0.startsWithToken("requirementdiagram") || $0.startsWithToken("requirement") },
        parseWithDiagnostics: { source, frontmatter in
            var (diagram, diagnostics) = try parseRequirementDiagram(DiagramSourceNormalizer.diagramLines(source), frontmatter: frontmatter)
            if let theme = frontmatter?.perDiagram.requirement.theme {
                diagram.config.theme = theme
            }
            return (diagram, diagnostics)
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
