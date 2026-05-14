import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _sequenceDiagram = _typed(
        type: .sequenceDiagram,
        matches: { $0.startsWithToken("sequencediagram") },
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
