import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _pie = DiagramDescriptor(
        type: .pie,
        matches: { $0.normalized.hasPrefix("pie") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.diagramLines(source)
            var chart = try parsePieChart(lines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.pieConfig { chart.config = cfg }
                if let theme = fm.pieTheme { chart.theme = theme }
                if chart.diagramTitle == nil, let fmTitle = fm.diagramTitle { chart.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .pie(chart))
        },
        layout: { graph, _ in
            guard case let .pie(chart) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.pie)
            }
            let positioned = layoutPieChart(chart)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .pie(positioned))
        }
    )
}
