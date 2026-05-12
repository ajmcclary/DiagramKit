import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// These descriptors are Mermaid-specific. A format-agnostic importer registry
// (ImporterRegistry + DiagramSourceImporter) will be introduced in Phase 1.
// At that point this type will become DiagramViewModelRegistry or be subsumed
// into MermaidImporter.
extension DiagramRegistry {
    static let _mindmap = DiagramDescriptor(
        type: .mindmap,
        matches: { $0.normalized.hasPrefix("mindmap") },
        parse: { source, frontmatter in
            let rawLines = DiagramSourceNormalizer.rawLines(source)
            let parsed = try parseMindmap(rawLines, frontmatter: frontmatter)
            return DiagramDocument(payload: .mindmap(parsed))
        },
        layout: { graph, _ in
            guard case let .mindmap(diagram) = graph.payload else {
                throw DiagramStructuralError.payloadMismatch(.mindmap)
            }
            #if canImport(UIKit) || canImport(AppKit)
            let positioned = try layoutMindmap(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .mindmap(positioned))
            #else
            // Linux: layoutMindmap depends on BMFont + NSAttributedString
            // text measurement. Unreachable until the portable text-measurement
            // shim lands.
            _ = diagram
            throw DiagramStructuralError.payloadMismatch(.mindmap)
            #endif
        }
    )
}
