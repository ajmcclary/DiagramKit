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
    static let _sequenceDiagram = _typed(
        type: .sequenceDiagram,
        matches: { $0.normalized.hasPrefix("sequencediagram") },
        parse: { source, _ in
            try parseSequenceDiagram(DiagramSourceNormalizer.diagramLines(source))
        },
        wrap: DiagramPayload.sequenceDiagram,
        unwrap: { payload in
            guard case let .sequenceDiagram(value) = payload else { return nil }
            return value
        },
        layout: { parsed, _ in try layoutSequenceDiagram(parsed) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .sequenceDiagram(
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
