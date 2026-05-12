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
    static let _zenuml = DiagramDescriptor(
        type: .zenuml,
        matches: { $0.normalized.hasPrefix("zenuml") },
        parse: { source, frontmatter in
            let rawLines = DiagramSourceNormalizer.rawLines(source)
            var parsed = try parseZenUMLDiagram(rawLines, frontmatter: frontmatter)
            parsed.useMaxWidth = frontmatter?.sequenceConfig?.useMaxWidth ?? true
            return DiagramDocument(payload: .zenuml(parsed))
        },
        layout: { graph, _ in
            guard case let .zenuml(parsed) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.zenuml)
            }
            let positioned = layoutZenUMLDiagram(parsed, useMaxWidth: parsed.useMaxWidth)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .zenuml(positioned))
        }
    )
}
