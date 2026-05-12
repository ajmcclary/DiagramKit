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
    static let _ishikawa = DiagramDescriptor(
        type: .ishikawa,
        matches: { header in
            _isIshikawaDiagramHeader(header.raw)
        },
        parse: { source, frontmatter in
            let rawLines = DiagramSourceNormalizer.rawLines(source)
            let diagram = try parseIshikawaDiagram(rawLines, frontmatter: frontmatter)
            return DiagramDocument(payload: .ishikawa(diagram))
        },
        layout: { graph, _ in
            guard case let .ishikawa(diagram) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.ishikawa)
            }
            #if canImport(CoreText)
            let positioned = layoutIshikawaDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .ishikawa(positioned))
            #else
            // Linux: layoutIshikawaDiagram requires CoreText for text-bounds
            // measurement. Unreachable until the portable text-measurement
            // shim lands (Stage 2.5 follow-up).
            _ = diagram
            throw DiagramStructuralError.payloadMismatch(.ishikawa)
            #endif
        }
    )
}
