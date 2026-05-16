import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _quadrantChart = _typed(
        type: .quadrantChart,
        matches: { $0.startsWithToken("quadrantchart") },
        parseWithDiagnostics: { source, frontmatter in
            var (chart, diagnostics) = try parseQuadrantChart(DiagramSourceNormalizer.diagramLines(source), frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.perDiagram.quadrant.config { chart.config = cfg }
                if let theme = fm.perDiagram.quadrant.theme { chart.theme = theme }
                if chart.diagramTitle == nil, let fmTitle = fm.shared.diagramTitle { chart.diagramTitle = fmTitle }
            }
            if chart.titleText == nil, let dt = chart.diagramTitle { chart.titleText = dt }
            return (chart, diagnostics)
        },
        wrap: DiagramPayload.quadrantChart,
        unwrap: { payload in
            guard case let .quadrantChart(value) = payload else { return nil }
            return value
        },
        layout: { chart, _ in layoutQuadrantChart(chart) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .quadrantChart(positioned))
        }
    )
}
