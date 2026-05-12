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
    static let _venn = DiagramDescriptor(
        type: .venn,
        matches: { $0.normalized.hasPrefix("venn-beta") },
        parse: { source, frontmatter in
            let rawLines = DiagramSourceNormalizer.rawLines(source)
            var diagram = try parseVennDiagram(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.vennConfig { diagram.config = cfg }
                if let theme = fm.theme { diagram.themeName = theme }
                if let tv = fm.vennThemeVariables { diagram.themeVariables = tv }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return DiagramDocument(payload: .venn(diagram))
        },
        layout: { graph, _ in
            guard case let .venn(diagram) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.venn)
            }
            let positioned = layoutVennDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .venn(positioned))
        }
    )
}
