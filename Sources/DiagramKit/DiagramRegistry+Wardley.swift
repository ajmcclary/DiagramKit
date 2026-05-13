import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _wardley = _typed(
        type: .wardleyBeta,
        matches: { $0.normalized.hasPrefix("wardley-beta") },
        parse: { source, frontmatter in
            var diagram = try parseWardleyMap(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.wardleyBetaConfig { diagram.config = cfg }
                if let theme = fm.wardleyTheme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return diagram
        },
        wrap: DiagramPayload.wardleyBeta,
        unwrap: { payload in
            guard case let .wardleyBeta(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in layoutWardleyMap(diagram) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .wardleyBeta(positioned))
        }
    )
}
