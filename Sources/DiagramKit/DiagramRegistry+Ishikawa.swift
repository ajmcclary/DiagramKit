import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _ishikawa = _typed(
        type: .ishikawa,
        matches: { header in _isIshikawaDiagramHeader(header.raw) },
        parseWithDiagnostics: { source, frontmatter in
            try parseIshikawaDiagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
        },
        wrap: DiagramPayload.ishikawa,
        unwrap: { payload in
            guard case let .ishikawa(value) = payload else { return nil }
            return value
        },
        layoutWithDiagnostics: { diagram, _ in
            return layoutIshikawaDiagram(diagram)
        },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .ishikawa(positioned))
        }
    )
}
