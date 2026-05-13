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
    static let _erDiagram = _typed(
        type: .erDiagram,
        matches: { $0.normalized.hasPrefix("erdiagram") },
        parse: { source, frontmatter in
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
                diagramTitle: positioned.diagramTitle
            ))
        }
    )
}
