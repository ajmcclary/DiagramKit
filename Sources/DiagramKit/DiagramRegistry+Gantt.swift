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
    static let _gantt = _typed(
        type: .gantt,
        matches: { $0.startsWithToken("gantt") },
        parse: { source, frontmatter in
            try parseGanttDiagram(
                DiagramSourceNormalizer.statements(source, separators: CharacterSet(charactersIn: "\n")),
                frontmatter: frontmatter
            )
        },
        wrap: DiagramPayload.gantt,
        unwrap: { payload in
            guard case let .gantt(value) = payload else { return nil }
            return value
        },
        layout: { parsed, _ in
            var merged = parsed
            merged.config = parsed.config ?? .default
            return layoutGanttDiagram(merged)
        },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .gantt(positioned))
        }
    )
}
