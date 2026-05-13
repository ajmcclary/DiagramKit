import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _c4 = _typed(
        type: .c4,
        matches: { $0.raw.range(of: #"^C4(?:Context|Container|Component|Dynamic|Deployment)\s*$"#, options: .regularExpression) != nil },
        parse: { source, frontmatter in
            try parseC4Diagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
        },
        wrap: DiagramPayload.c4,
        unwrap: { payload in
            guard case let .c4(value) = payload else { return nil }
            return value
        },
        layout: { parsed, _ in layoutC4Diagram(parsed) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .c4(positioned))
        }
    )
}
