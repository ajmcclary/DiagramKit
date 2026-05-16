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
        parseWithDiagnostics: { source, frontmatter in
            var (diagram, diagnostics) = try parseRadarDiagram(source: source, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.perDiagram.radar.config { diagram.config = cfg }
                if let theme = fm.perDiagram.radar.theme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.shared.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return (diagram, diagnostics)
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
