import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _architecture = DiagramDescriptor(
        type: .architecture,
        matches: { $0.normalized.hasPrefix("architecture") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            var diagram = try parseArchitectureDiagram(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.archConfig { diagram.config = cfg }
                if let theme = fm.archTheme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .architecture(diagram))
        },
        layout: { graph, _ in
            guard case let .architecture(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.architecture)
            }
            let positioned = layoutArchitectureDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .architecture(positioned))
        }
    )
}
