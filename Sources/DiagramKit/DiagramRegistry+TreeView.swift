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
                if let cfg = fm.treeViewConfig { diagram.config = cfg }
                if let theme = fm.treeViewTheme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return (diagram, diagnostics)
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
        },
        linuxSupport: false,
        linuxUnsupportedReason: "requires CoreText text-measurement"
    )
}
