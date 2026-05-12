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
    static let _treemap = DiagramDescriptor(
        type: .treemap,
        matches: { $0.normalized.hasPrefix("treemap") },
        parse: { source, frontmatter in
            let rawLines = DiagramSourceNormalizer.rawLines(source)
            var diagram = try parseTreemapDiagram(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.treemapConfig { diagram.config = cfg }
                if let theme = fm.theme { diagram.themeName = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return DiagramDocument(payload: .treemap(diagram))
        },
        layout: { graph, _ in
            guard case let .treemap(diagram) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.treemap)
            }
            let positioned = layoutTreemapDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .treemap(positioned))
        }
    )
}
