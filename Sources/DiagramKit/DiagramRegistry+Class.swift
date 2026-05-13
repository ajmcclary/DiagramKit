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
    static let _classDiagram = _typed(
        type: .classDiagram,
        matches: { $0.normalized.hasPrefix("classdiagram") },
        parse: { source, frontmatter in
            try parseClassDiagram(DiagramSourceNormalizer.diagramLines(source), frontmatter: frontmatter)
        },
        wrap: DiagramPayload.classDiagram,
        unwrap: { payload in
            guard case let .classDiagram(value) = payload else { return nil }
            return value
        },
        layout: { parsed, _ in try layoutClassDiagramSync(parsed) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .classDiagram(
                classes: positioned.classes, relationships: positioned.relationships,
                namespaces: positioned.namespaces, notes: positioned.notes,
                accTitle: positioned.accTitle, accDescr: positioned.accDescription,
                diagramTitle: positioned.diagramTitle
            ))
        }
    )
}
