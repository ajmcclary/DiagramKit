import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _pie = _typed(
        type: .pie,
        matches: { $0.startsWithToken("pie") },
        parse: { source, frontmatter in
            var chart = try parsePieChart(DiagramSourceNormalizer.diagramLines(source), frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.pieConfig { chart.config = cfg }
                if let theme = fm.pieTheme { chart.theme = theme }
                if chart.diagramTitle == nil, let fmTitle = fm.diagramTitle { chart.diagramTitle = fmTitle }
            }
            return chart
        },
        wrap: DiagramPayload.pie,
        unwrap: { payload in
            guard case let .pie(value) = payload else { return nil }
            return value
        },
        layout: { chart, _ in layoutPieChart(chart) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .pie(positioned))
        }
    )
}
