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
    static let _quadrantChart = _typed(
        type: .quadrantChart,
        matches: { $0.normalized.hasPrefix("quadrantchart") },
        parse: { source, frontmatter in
            var chart = try parseQuadrantChart(DiagramSourceNormalizer.diagramLines(source), frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.quadrantChartConfig { chart.config = cfg }
                if let theme = fm.quadrantChartTheme { chart.theme = theme }
                if chart.diagramTitle == nil, let fmTitle = fm.diagramTitle { chart.diagramTitle = fmTitle }
            }
            if chart.titleText == nil, let dt = chart.diagramTitle { chart.titleText = dt }
            return chart
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
