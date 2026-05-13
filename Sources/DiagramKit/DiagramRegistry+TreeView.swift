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
    static let _treeView = _typed(
        type: .treeView,
        matches: { header in _isTreeViewHeader(rawLines: header.rawLines) },
        parse: { source, frontmatter in
            var diagram = try parseTreeViewDiagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.treeViewConfig { diagram.config = cfg }
                if let theme = fm.treeViewTheme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return diagram
        },
        wrap: DiagramPayload.treeView,
        unwrap: { payload in
            guard case let .treeView(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in
            #if canImport(UIKit) || canImport(AppKit)
            return layoutTreeViewDiagram(diagram)
            #else
            // Linux: layoutTreeViewDiagram depends on BMColor + CTLine.
            // Unreachable until the portable text-measurement shim lands.
            _ = diagram
            throw DiagramStructuralError.payloadMismatch(.treeView)
            #endif
        },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.viewBoxWidth, height: positioned.viewBoxHeight, content: .treeView(positioned))
        }
    )
}
