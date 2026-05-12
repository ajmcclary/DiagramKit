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
    static let _treeView = DiagramDescriptor(
        type: .treeView,
        matches: { header in
            _isTreeViewHeader(rawLines: header.rawLines)
        },
        parse: { source, frontmatter in
            let rawLines = DiagramSourceNormalizer.rawLines(source)
            var diagram = try parseTreeViewDiagram(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.treeViewConfig { diagram.config = cfg }
                if let theme = fm.treeViewTheme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return DiagramDocument(payload: .treeView(diagram))
        },
        layout: { graph, _ in
            guard case let .treeView(diagram) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.treeView)
            }
            #if canImport(UIKit) || canImport(AppKit)
            let positioned = layoutTreeViewDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.viewBoxWidth, height: positioned.viewBoxHeight, content: .treeView(positioned))
            #else
            // Linux: layoutTreeViewDiagram depends on BMColor + CTLine.
            // Unreachable until the portable text-measurement shim lands.
            _ = diagram
            throw DiagramStructuralError.payloadMismatch(.treeView)
            #endif
        }
    )
}
