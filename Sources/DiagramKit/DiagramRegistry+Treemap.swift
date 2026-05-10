import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _treemap = DiagramDescriptor(
        type: .treemap,
        matches: { $0.normalized.hasPrefix("treemap") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            var diagram = try parseTreemapDiagram(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.treemapConfig { diagram.config = cfg }
                if let theme = fm.theme { diagram.themeName = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .treemap(diagram))
        },
        layout: { graph, _ in
            guard case let .treemap(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.treemap)
            }
            let positioned = layoutTreemapDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .treemap(positioned))
        }
    )
}
