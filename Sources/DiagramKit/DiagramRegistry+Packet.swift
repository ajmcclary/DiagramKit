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
    static let _packet = DiagramDescriptor(
        type: .packet,
        matches: { $0.normalized.hasPrefix("packet") },
        parse: { source, frontmatter in
            let lines = DiagramSourceNormalizer.statements(source)
            let parsed = try parsePacketDiagram(lines, frontmatter: frontmatter)
            return DiagramDocument(payload: .packet(parsed))
        },
        layout: { graph, _ in
            guard case let .packet(diagram) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.packet)
            }
            let positioned = layoutPacketDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .packet(positioned))
        }
    )
}
