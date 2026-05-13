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
    static let _venn = _typed(
        type: .venn,
        matches: { $0.normalized.hasPrefix("venn-beta") },
        parse: { source, frontmatter in
            var diagram = try parseVennDiagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.vennConfig { diagram.config = cfg }
                if let theme = fm.theme { diagram.themeName = theme }
                if let tv = fm.vennThemeVariables { diagram.themeVariables = tv }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return diagram
        },
        wrap: DiagramPayload.venn,
        unwrap: { payload in
            guard case let .venn(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in layoutVennDiagram(diagram) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .venn(positioned))
        }
    )
}
