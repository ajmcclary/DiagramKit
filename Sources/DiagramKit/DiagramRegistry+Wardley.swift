import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _wardley = DiagramDescriptor(
        type: .wardleyBeta,
        matches: { $0.normalized.hasPrefix("wardley-beta") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            var diagram = try parseWardleyMap(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.wardleyBetaConfig { diagram.config = cfg }
                if let theme = fm.wardleyTheme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .wardleyBeta(diagram))
        },
        layout: { graph, _ in
            guard case let .wardleyBeta(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.wardleyBeta)
            }
            let positioned = layoutWardleyMap(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .wardleyBeta(positioned))
        }
    )
}
