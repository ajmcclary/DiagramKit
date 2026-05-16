import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _treeView = _typed(
        type: .treeView,
        matches: { header in _isTreeViewHeader(rawLines: header.rawLines) },
        parseWithDiagnostics: { source, frontmatter in
            var (diagram, diagnostics) = try parseTreeViewDiagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.perDiagram.treeView.config { diagram.config = cfg }
                if let theme = fm.perDiagram.treeView.theme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.shared.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return (diagram, diagnostics)
        },
        wrap: DiagramPayload.treeView,
        unwrap: { payload in
            guard case let .treeView(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in
            return layoutTreeViewDiagram(diagram)
        },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.viewBoxWidth, height: positioned.viewBoxHeight, content: .treeView(positioned))
        }
    )
}
