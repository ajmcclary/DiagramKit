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
    // State and flowchart cross-emit each other's payload (the parser may
    // rewrite `.flowchart` -> `.stateDiagram`), so the descriptor is built
    // with the explicit initializer rather than the typed factory whose
    // strict `unwrap` cannot express that branching.
    static let _stateDiagram = DiagramDescriptor(
        type: .stateDiagram,
        matches: { $0.normalized.hasPrefix("statediagram") || $0.normalized == "state" },
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
