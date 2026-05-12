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
    static let _classDiagram = DiagramDescriptor(
        type: .classDiagram,
        matches: { $0.normalized.hasPrefix("classdiagram") },
        parse: { source, frontmatter in
            let lines = DiagramSourceNormalizer.diagramLines(source)
            let parsed = try parseClassDiagram(lines, frontmatter: frontmatter)
            return DiagramDocument(payload: .classDiagram(parsed))
        },
        layout: { graph, _ in
            guard case let .classDiagram(parsed) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.classDiagram)
            }
            let positioned = try layoutClassDiagramSync(parsed)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .classDiagram(
                classes: positioned.classes, relationships: positioned.relationships,
                namespaces: positioned.namespaces, notes: positioned.notes,
                accTitle: positioned.accTitle, accDescr: positioned.accDescription,
                diagramTitle: positioned.diagramTitle
            ))
        }
    )
}
