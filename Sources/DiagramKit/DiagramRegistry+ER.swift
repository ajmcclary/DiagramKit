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
    static let _erDiagram = DiagramDescriptor(
        type: .erDiagram,
        matches: { $0.normalized.hasPrefix("erdiagram") },
        parse: { source, frontmatter in
            let lines = DiagramSourceNormalizer.diagramLines(source)
            let parsed = try parseErDiagram(lines, frontmatter: frontmatter)
            return DiagramDocument(payload: .erDiagram(parsed))
        },
        layout: { graph, _ in
            guard case let .erDiagram(parsed) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.erDiagram)
            }
            let positioned = try layoutErDiagramSync(parsed, config: parsed.config)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .erDiagram(
                entities: positioned.entities, relationships: positioned.relationships,
                accTitle: positioned.accTitle, accDescr: positioned.accDescr,
                diagramTitle: positioned.diagramTitle
            ))
        }
    )
}
