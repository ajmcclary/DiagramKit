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
    static let _xyChart = DiagramDescriptor(
        type: .xyChart,
        matches: { $0.normalized.hasPrefix("xychart") },
        parse: { source, frontmatter in
            let lines = DiagramSourceNormalizer.diagramLines(source)
            var chart = try parseXYChart(lines)
            if let fm = frontmatter {
                chart.config = fm.xyChartConfig
                chart.theme = fm.xyChartTheme
                if chart.titleText == nil, let fmTitle = fm.diagramTitle { chart.diagramTitle = fmTitle }
            }
            return DiagramDocument(payload: .xyChart(chart))
        },
        layout: { graph, _ in
            guard case let .xyChart(chart) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.xyChart)
            }
            let positioned = layoutXYChart(chart)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .xyChart(positioned))
        }
    )
}
