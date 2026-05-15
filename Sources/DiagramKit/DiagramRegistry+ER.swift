import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _erDiagram = _typed(
        type: .erDiagram,
        matches: { $0.startsWithToken("erdiagram") },
        parseWithDiagnostics: { source, frontmatter in
            try parseErDiagram(DiagramSourceNormalizer.diagramLines(source), frontmatter: frontmatter)
        },
        wrap: DiagramPayload.erDiagram,
        unwrap: { payload in
            guard case let .erDiagram(value) = payload else { return nil }
            return value
        },
        layout: { parsed, _ in try layoutErDiagramSync(parsed, config: parsed.config) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .erDiagram(
                entities: positioned.entities, relationships: positioned.relationships,
                accTitle: positioned.accTitle, accDescr: positioned.accDescr,
                diagramTitle: positioned.diagramTitle,
                config: positioned.config
            ))
        }
    )
}
