import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _zenuml = _typed(
        type: .zenuml,
        matches: { $0.startsWithToken("zenuml") },
        parseWithDiagnostics: { source, frontmatter in
            var (parsed, diagnostics) = try parseZenUMLDiagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
            parsed.useMaxWidth = frontmatter?.perDiagram.sequence.config?.useMaxWidth ?? true
            return (parsed, diagnostics)
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
