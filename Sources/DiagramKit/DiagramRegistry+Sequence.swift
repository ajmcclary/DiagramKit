import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _sequenceDiagram = DiagramDescriptor(
        type: .sequenceDiagram,
        matches: { $0.normalized.hasPrefix("sequencediagram") },
        parse: { source, _ in
            let lines = MermaidSourceNormalizer.diagramLines(source)
            let parsed = try parseSequenceDiagram(lines)
            return MermaidGraph(payload: .sequenceDiagram(parsed))
        },
        layout: { graph, _ in
            guard case let .sequenceDiagram(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.sequenceDiagram)
            }
            let positioned = try layoutSequenceDiagram(parsed)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .sequenceDiagram(
                actors: positioned.actors, messages: positioned.messages,
                blocks: positioned.blocks, lifelines: positioned.lifelines,
                activations: positioned.activations, notes: positioned.notes,
                boxes: positioned.boxes, bottomActors: positioned.bottomActors,
                rectHighlights: positioned.rectHighlights,
                title: positioned.title, accTitle: positioned.accTitle, accDescr: positioned.accDescr
            ))
        }
    )
}
