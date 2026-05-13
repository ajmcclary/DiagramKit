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
    static let _block = _typed(
        type: .block,
        matches: { $0.startsWithToken("block") },
        parse: { source, frontmatter in
            try parseBlockDiagram(source, frontmatter: frontmatter)
        },
        wrap: DiagramPayload.block,
        unwrap: { payload in
            guard case let .block(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in try layoutBlockDiagram(diagram) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .block(positioned))
        }
    )
}
