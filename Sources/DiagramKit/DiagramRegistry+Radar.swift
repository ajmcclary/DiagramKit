import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _radar = DiagramDescriptor(
        type: .radar,
        matches: { $0.normalized.hasPrefix("radar-beta") },
        parse: { source, frontmatter in
            var diagram = try parseRadarDiagram(source: source, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.radarConfig { diagram.config = cfg }
                if let theme = fm.radarTheme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .radar(diagram))
        },
        layout: { graph, _ in
            guard case let .radar(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.radar)
            }
            let positioned = layoutRadarDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .radar(positioned))
        }
    )
}
