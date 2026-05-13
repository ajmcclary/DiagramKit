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
    static let _ishikawa = _typed(
        type: .ishikawa,
        matches: { header in _isIshikawaDiagramHeader(header.raw) },
        parse: { source, frontmatter in
            try parseIshikawaDiagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
        },
        wrap: DiagramPayload.ishikawa,
        unwrap: { payload in
            guard case let .ishikawa(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in
            #if canImport(CoreText)
            return layoutIshikawaDiagram(diagram)
            #else
            // Linux: layoutIshikawaDiagram requires CoreText for text-bounds
            // measurement. Unreachable until the portable text-measurement
            // shim lands (Stage 2.5 follow-up).
            _ = diagram
            throw DiagramStructuralError.payloadMismatch(.ishikawa)
            #endif
        },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .ishikawa(positioned))
        }
    )
}
