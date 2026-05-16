import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _treemap = _typed(
        type: .treemap,
        matches: { $0.startsWithToken("treemap") },
        parseWithDiagnostics: { source, frontmatter in
            var (diagram, diagnostics) = try parseTreemapDiagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.perDiagram.treemap.config { diagram.config = cfg }
                if let theme = fm.shared.theme { diagram.themeName = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.shared.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return (diagram, diagnostics)
        },
        wrap: DiagramPayload.treemap,
        unwrap: { payload in
            guard case let .treemap(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in layoutTreemapDiagram(diagram) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .treemap(positioned))
        }
    )
}
