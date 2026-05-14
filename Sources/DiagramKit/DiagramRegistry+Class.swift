import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _classDiagram = _typed(
        type: .classDiagram,
        matches: { $0.startsWithToken("classdiagram") },
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
