import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _c4 = DiagramDescriptor(
        type: .c4,
        matches: { $0.raw.range(of: #"^C4(?:Context|Container|Component|Dynamic|Deployment)\s*$"#, options: .regularExpression) != nil },
        parse: { source, frontmatter in
            let (diagram, diagnostics) = try parseC4Diagram(
                DiagramSourceNormalizer.rawLines(source),
                frontmatter: frontmatter
            )
            return (DiagramDocument(payload: .c4(diagram)), diagnostics)
        },
        layout: { graph, _ in
            guard case let .c4(diagram) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.c4)
            }
            let positioned = layoutC4Diagram(diagram)
            let result = PositionedGraph(
                diagram: graph,
                width: positioned.width,
                height: positioned.height,
                content: .c4(positioned)
            )
            return (result, [])
        }
    )
}
