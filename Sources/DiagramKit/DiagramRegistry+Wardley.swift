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
