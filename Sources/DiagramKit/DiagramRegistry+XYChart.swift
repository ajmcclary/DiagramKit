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
    static let _xyChart = _typed(
        type: .xyChart,
        matches: { $0.normalized.hasPrefix("xychart") },
        parse: { source, frontmatter in
            var chart = try parseXYChart(DiagramSourceNormalizer.diagramLines(source))
            if let fm = frontmatter {
                chart.config = fm.xyChartConfig
                chart.theme = fm.xyChartTheme
                if chart.titleText == nil, let fmTitle = fm.diagramTitle { chart.diagramTitle = fmTitle }
            }
            return chart
        },
        wrap: DiagramPayload.xyChart,
        unwrap: { payload in
            guard case let .xyChart(value) = payload else { return nil }
            return value
        },
        layout: { chart, _ in layoutXYChart(chart) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .xyChart(positioned))
        }
    )
}
