import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _ishikawa = DiagramDescriptor(
        type: .ishikawa,
        matches: { header in
            _isIshikawaDiagramHeader(header.raw)
        },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            let diagram = try parseIshikawaDiagram(rawLines, frontmatter: frontmatter)
            return MermaidGraph(payload: .ishikawa(diagram))
        },
        layout: { graph, _ in
            guard case let .ishikawa(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.ishikawa)
            }
            #if canImport(CoreText)
            let positioned = layoutIshikawaDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .ishikawa(positioned))
            #else
            // Linux: layoutIshikawaDiagram requires CoreText for text-bounds
            // measurement. Unreachable until the portable text-measurement
            // shim lands (Stage 2.5 follow-up).
            _ = diagram
            throw MermaidStructuralError.payloadMismatch(.ishikawa)
            #endif
        }
    )
}
