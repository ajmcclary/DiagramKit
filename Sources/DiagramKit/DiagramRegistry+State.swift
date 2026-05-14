import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    // State and flowchart cross-emit each other's payload (the parser may
    // rewrite `.flowchart` -> `.stateDiagram`), so the descriptor is built
    // with the explicit initializer rather than the typed factory whose
    // strict `unwrap` cannot express that branching.
    static let _stateDiagram = DiagramDescriptor(
        type: .stateDiagram,
        matches: { $0.startsWithToken("statediagram") || $0.startsWithToken("state") },
        parse: { source, frontmatter in
            let parsed = try parseMermaid(source, config: frontmatter?.flowchartConfig, stateConfig: frontmatter?.stateConfig)
            switch parsed.payload {
            case .flowchart(let model), .stateDiagram(let model):
                return DiagramDocument(payload: .stateDiagram(model))
            default:
                return parsed
            }
        },
        layout: { graph, config in
            try layoutGraphSync(graph, config: config)
        }
    )
}
