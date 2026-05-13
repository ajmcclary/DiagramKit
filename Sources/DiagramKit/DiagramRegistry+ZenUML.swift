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
    static let _zenuml = _typed(
        type: .zenuml,
        matches: { $0.normalized.hasPrefix("zenuml") },
        parse: { source, frontmatter in
            var parsed = try parseZenUMLDiagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
            parsed.useMaxWidth = frontmatter?.sequenceConfig?.useMaxWidth ?? true
            return parsed
        },
        wrap: DiagramPayload.zenuml,
        unwrap: { payload in
            guard case let .zenuml(value) = payload else { return nil }
            return value
        },
        layout: { parsed, _ in layoutZenUMLDiagram(parsed, useMaxWidth: parsed.useMaxWidth) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .zenuml(positioned))
        }
    )
}
