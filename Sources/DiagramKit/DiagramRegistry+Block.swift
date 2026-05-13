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
    static let _block = DiagramDescriptor(
        type: .block,
        matches: { $0.startsWithToken("block") },
        parse: { source, frontmatter in
            let parsed = try parseBlockDiagram(source, frontmatter: frontmatter)
            return DiagramDocument(payload: .block(parsed))
        },
        layout: { graph, _ in
            guard case let .block(diagram) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.block)
            }
            let positioned = try layoutBlockDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .block(positioned))
        }
    )
}
