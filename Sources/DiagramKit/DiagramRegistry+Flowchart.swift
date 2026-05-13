import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    // Fallback descriptor — `matches: { _ in true }` ensures every header
    // that wasn't claimed by a more specific descriptor lands here.
    static let _flowchart = DiagramDescriptor(
        type: .flowchart,
        matches: { _ in true },
        parse: { source, frontmatter in
            let parsed = try parseMermaid(source, config: frontmatter?.flowchartConfig, stateConfig: frontmatter?.stateConfig)
            switch parsed.payload {
            case .flowchart(let model), .stateDiagram(let model):
                return DiagramDocument(payload: .flowchart(model))
            default:
                return parsed
            }
        },
        layout: { graph, config in
            try layoutGraphSync(graph, config: config)
        }
    )
}
