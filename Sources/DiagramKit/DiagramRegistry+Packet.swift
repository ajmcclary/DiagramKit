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
    static let _packet = _typed(
        type: .packet,
        matches: { $0.normalized.hasPrefix("packet") },
        parse: { source, frontmatter in
            try parsePacketDiagram(DiagramSourceNormalizer.statements(source), frontmatter: frontmatter)
        },
        wrap: DiagramPayload.packet,
        unwrap: { payload in
            guard case let .packet(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in layoutPacketDiagram(diagram) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .packet(positioned))
        }
    )
}
