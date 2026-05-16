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
        matches: { $0.startsWithToken("wardley-beta") },
        parseWithDiagnostics: { source, frontmatter in
            var (diagram, diagnostics) = try parseWardleyMap(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.perDiagram.wardley.config { diagram.config = cfg }
                if let theme = fm.perDiagram.wardley.theme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.shared.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return (diagram, diagnostics)
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
