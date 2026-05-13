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
    static let _treemap = _typed(
        type: .treemap,
        matches: { $0.normalized.hasPrefix("treemap") },
        parse: { source, frontmatter in
            var diagram = try parseTreemapDiagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.treemapConfig { diagram.config = cfg }
                if let theme = fm.theme { diagram.themeName = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return diagram
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
