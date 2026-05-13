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
