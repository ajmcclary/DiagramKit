import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _xyChart = DiagramDescriptor(
        type: .xyChart,
        matches: { $0.normalized.hasPrefix("xychart") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.diagramLines(source)
            var chart = try parseXYChart(lines)
            if let fm = frontmatter {
                chart.config = fm.xyChartConfig
                chart.theme = fm.xyChartTheme
                if chart.titleText == nil, let fmTitle = fm.diagramTitle { chart.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .xyChart(chart))
        },
        layout: { graph, _ in
            guard case let .xyChart(chart) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.xyChart)
            }
            let positioned = layoutXYChart(chart)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .xyChart(positioned))
        }
    )
}
