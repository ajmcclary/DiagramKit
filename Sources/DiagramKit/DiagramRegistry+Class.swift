import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _classDiagram = DiagramDescriptor(
        type: .classDiagram,
        matches: { $0.normalized.hasPrefix("classdiagram") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.diagramLines(source)
            let parsed = try parseClassDiagram(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .classDiagram(parsed))
        },
        layout: { graph, _ in
            guard case let .classDiagram(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.classDiagram)
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
