import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _quadrantChart = DiagramDescriptor(
        type: .quadrantChart,
        matches: { $0.normalized.hasPrefix("quadrantchart") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.diagramLines(source)
            var chart = try parseQuadrantChart(lines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.quadrantChartConfig { chart.config = cfg }
                if let theme = fm.quadrantChartTheme { chart.theme = theme }
                if chart.diagramTitle == nil, let fmTitle = fm.diagramTitle { chart.diagramTitle = fmTitle }
            }
            if chart.titleText == nil, let dt = chart.diagramTitle { chart.titleText = dt }
            return MermaidGraph(payload: .quadrantChart(chart))
        },
        layout: { graph, _ in
            guard case let .quadrantChart(chart) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.quadrantChart)
            }
            let positioned = layoutQuadrantChart(chart)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .quadrantChart(positioned))
        }
    )
}
