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
    static let _architecture = DiagramDescriptor(
        type: .architecture,
        matches: { $0.normalized.hasPrefix("architecture") },
        parse: { source, frontmatter in
            let rawLines = DiagramSourceNormalizer.rawLines(source)
            var diagram = try parseArchitectureDiagram(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.archConfig { diagram.config = cfg }
                if let theme = fm.archTheme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return DiagramDocument(payload: .architecture(diagram))
        },
        layout: { graph, _ in
            guard case let .architecture(diagram) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.architecture)
            }
            let positioned = layoutArchitectureDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .architecture(positioned))
        }
    )
}
