import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _erDiagram = DiagramDescriptor(
        type: .erDiagram,
        matches: { $0.normalized.hasPrefix("erdiagram") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.diagramLines(source)
            let parsed = try parseErDiagram(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .erDiagram(parsed))
        },
        layout: { graph, _ in
            guard case let .erDiagram(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.erDiagram)
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
