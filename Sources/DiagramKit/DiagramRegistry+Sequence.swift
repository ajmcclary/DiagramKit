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
    static let _sequenceDiagram = DiagramDescriptor(
        type: .sequenceDiagram,
        matches: { $0.normalized.hasPrefix("sequencediagram") },
        parse: { source, _ in
            let lines = DiagramSourceNormalizer.diagramLines(source)
            let parsed = try parseSequenceDiagram(lines)
            return DiagramDocument(payload: .sequenceDiagram(parsed))
        },
        layout: { graph, _ in
            guard case let .sequenceDiagram(parsed) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.sequenceDiagram)
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
