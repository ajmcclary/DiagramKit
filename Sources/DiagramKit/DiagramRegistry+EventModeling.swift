import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _eventModeling = _typed(
        type: .eventModeling,
        matches: { $0.startsWithToken("eventmodeling") },
        parseWithDiagnostics: { source, frontmatter in
            var (diagram, diagnostics) = try parseEventModeling(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.eventmodelingConfig { diagram.config = cfg }
                if let theme = fm.eventmodelingThemeVariables { diagram.themeVariables = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return (diagram, diagnostics)
        },
        wrap: DiagramPayload.eventModeling,
        unwrap: { payload in
            guard case let .eventModeling(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in
            #if canImport(CoreText)
            return layoutEventModeling(diagram)
            #else
            // Linux: layoutEventModeling requires CoreText for text-bounds
            // measurement. Unreachable until the portable text-measurement
            // shim lands.
            _ = diagram
            throw DiagramStructuralError.payloadMismatch(.eventModeling)
            #endif
        },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .eventModeling(positioned))
        }
    )
}
