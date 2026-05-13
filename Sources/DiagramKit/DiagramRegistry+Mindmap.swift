import Foundation
import DiagramKitModel
import DiagramKitCommon


// MARK: Mermaid-internal diagram-family registry
//
// Mermaid-family descriptors. Format-agnostic source dispatch lives in
// DiagramKitImport (`ImporterRegistry` + `DiagramSourceImporter`). This
// registry remains as the Mermaid family detector and descriptor catalog.
extension DiagramRegistry {
    static let _mindmap = _typed(
        type: .mindmap,
        matches: { $0.normalized.hasPrefix("mindmap") },
        parse: { source, frontmatter in
            try parseMindmap(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
        },
        wrap: DiagramPayload.mindmap,
        unwrap: { payload in
            guard case let .mindmap(value) = payload else { return nil }
            return value
        },
        layout: { diagram, _ in
            #if canImport(UIKit) || canImport(AppKit)
            return try layoutMindmap(diagram)
            #else
            // Linux: layoutMindmap depends on BMFont + NSAttributedString
            // text measurement. Unreachable until the portable text-measurement
            // shim lands.
            _ = diagram
            throw DiagramStructuralError.payloadMismatch(.mindmap)
            #endif
        },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .mindmap(positioned))
        }
    )
}
