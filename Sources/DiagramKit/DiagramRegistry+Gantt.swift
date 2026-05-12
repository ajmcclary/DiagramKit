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
    static let _gantt = DiagramDescriptor(
        type: .gantt,
        matches: { $0.normalized.hasPrefix("gantt") },
        parse: { source, frontmatter in
            let lines = DiagramSourceNormalizer.statements(source, separators: CharacterSet(charactersIn: "\n"))
            let parsed = try parseGanttDiagram(lines, frontmatter: frontmatter)
            return DiagramDocument(payload: .gantt(parsed))
        },
        layout: { graph, _ in
            guard case let .gantt(parsed) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.gantt)
            }
            let config = parsed.config ?? .default
            var merged = parsed
            merged.config = config
            let positioned = layoutGanttDiagram(merged)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .gantt(positioned))
        }
    )
}
