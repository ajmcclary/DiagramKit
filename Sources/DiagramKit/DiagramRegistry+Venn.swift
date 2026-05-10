import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _venn = DiagramDescriptor(
        type: .venn,
        matches: { $0.normalized.hasPrefix("venn-beta") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            var diagram = try parseVennDiagram(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.vennConfig { diagram.config = cfg }
                if let theme = fm.theme { diagram.themeName = theme }
                if let tv = fm.vennThemeVariables { diagram.themeVariables = tv }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .venn(diagram))
        },
        layout: { graph, _ in
            guard case let .venn(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.venn)
            }
            let positioned = layoutVennDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .venn(positioned))
        }
    )
}
