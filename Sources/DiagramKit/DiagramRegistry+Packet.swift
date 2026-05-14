import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _packet = _typed(
        type: .packet,
        matches: { $0.startsWithToken("packet") },
        parseWithDiagnostics: { source, frontmatter in
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
