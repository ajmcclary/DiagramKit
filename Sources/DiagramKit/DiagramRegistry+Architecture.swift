import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _architecture = _typed(
        type: .architecture,
        matches: { $0.normalized.hasPrefix("architecture") },
        parse: { source, frontmatter in
            var diagram = try parseArchitectureDiagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.archConfig { diagram.config = cfg }
                if let theme = fm.archTheme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return diagram
        },
        wrap: DiagramPayload.architecture,
        unwrap: { payload in
            guard case let .architecture(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in layoutArchitectureDiagram(diagram) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .architecture(positioned))
        }
    )
}
