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
    static let _pie = DiagramDescriptor(
        type: .pie,
        matches: { $0.startsWithToken("pie") },
        parse: { source, frontmatter in
            let lines = DiagramSourceNormalizer.diagramLines(source)
            var chart = try parsePieChart(lines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.pieConfig { chart.config = cfg }
                if let theme = fm.pieTheme { chart.theme = theme }
                if chart.diagramTitle == nil, let fmTitle = fm.diagramTitle { chart.diagramTitle = fmTitle }
            }
            return DiagramDocument(payload: .pie(chart))
        },
        layout: { graph, _ in
            guard case let .pie(chart) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.pie)
            }
            let positioned = layoutPieChart(chart)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .pie(positioned))
        }
    )
}
