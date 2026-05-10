import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _eventModeling = DiagramDescriptor(
        type: .eventModeling,
        matches: { $0.normalized.hasPrefix("eventmodeling") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            var diagram = try parseEventModeling(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.eventmodelingConfig { diagram.config = cfg }
                if let theme = fm.eventmodelingThemeVariables { diagram.themeVariables = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .eventModeling(diagram))
        },
        layout: { graph, _ in
            guard case let .eventModeling(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.eventModeling)
            }
            #if canImport(CoreText)
            let positioned = layoutEventModeling(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .eventModeling(positioned))
            #else
            // Linux: layoutEventModeling requires CoreText for text-bounds
            // measurement. Unreachable until the portable text-measurement
            // shim lands.
            _ = diagram
            throw MermaidStructuralError.payloadMismatch(.eventModeling)
            #endif
        }
    )
}
