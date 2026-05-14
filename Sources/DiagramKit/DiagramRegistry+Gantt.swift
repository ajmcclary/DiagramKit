import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _gantt = _typed(
        type: .gantt,
        matches: { $0.startsWithToken("gantt") },
        parseWithDiagnostics: { source, frontmatter in
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
