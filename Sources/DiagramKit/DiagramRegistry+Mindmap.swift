import Foundation
import DiagramKitModel
import DiagramKitCommon

extension DiagramRegistry {
    static let _mindmap = DiagramDescriptor(
        type: .mindmap,
        matches: { $0.normalized.hasPrefix("mindmap") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            let parsed = try parseMindmap(rawLines, frontmatter: frontmatter)
            return MermaidGraph(payload: .mindmap(parsed))
        },
        layout: { graph, _ in
            guard case let .mindmap(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.mindmap)
            }
            #if canImport(UIKit) || canImport(AppKit)
            let positioned = try layoutMindmap(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .mindmap(positioned))
            #else
            // Linux: layoutMindmap depends on BMFont + NSAttributedString
            // text measurement. Unreachable until the portable text-measurement
            // shim lands.
            _ = diagram
            throw MermaidStructuralError.payloadMismatch(.mindmap)
            #endif
        }
    )
}
