import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _radar = _typed(
        type: .radar,
        matches: { $0.startsWithToken("radar-beta") },
        parse: { source, frontmatter in
            var diagram = try parseRadarDiagram(source: source, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.radarConfig { diagram.config = cfg }
                if let theme = fm.radarTheme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return diagram
        },
        wrap: DiagramPayload.radar,
        unwrap: { payload in
            guard case let .radar(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in layoutRadarDiagram(diagram) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .radar(positioned))
        }
    )
}
