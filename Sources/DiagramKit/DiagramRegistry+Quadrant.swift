import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// These descriptors are Mermaid-specific. A format-agnostic importer registry
// (ImporterRegistry + DiagramSourceImporter) will be introduced in Phase 1.
// At that point this type will become DiagramViewModelRegistry or be subsumed
// into MermaidImporter.
extension DiagramRegistry {
    static let _quadrantChart = DiagramDescriptor(
        type: .quadrantChart,
        matches: { $0.normalized.hasPrefix("quadrantchart") },
        parse: { source, frontmatter in
            let lines = DiagramSourceNormalizer.diagramLines(source)
            var chart = try parseQuadrantChart(lines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.quadrantChartConfig { chart.config = cfg }
                if let theme = fm.quadrantChartTheme { chart.theme = theme }
                if chart.diagramTitle == nil, let fmTitle = fm.diagramTitle { chart.diagramTitle = fmTitle }
            }
            if chart.titleText == nil, let dt = chart.diagramTitle { chart.titleText = dt }
            return DiagramDocument(payload: .quadrantChart(chart))
        },
        layout: { graph, _ in
            guard case let .quadrantChart(chart) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.quadrantChart)
            }
            let positioned = layoutQuadrantChart(chart)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .quadrantChart(positioned))
        }
    )
}
