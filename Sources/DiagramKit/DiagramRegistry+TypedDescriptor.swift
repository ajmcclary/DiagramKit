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

    /// Build a `DiagramDescriptor` from typed parse + layout closures.
    ///
    /// Removes the repeated `guard case let .X(parsed) = graph.payload else { throw }`
    /// boilerplate used by every per-family descriptor, and the matching
    /// `DiagramDocument(payload: .X(parsed))` wrap on the way out. The factory
    /// is internal to the umbrella; per-family extension files in
    /// `DiagramRegistry+<Family>.swift` consume it. Use the original
    /// `DiagramDescriptor(...)` initializer directly for descriptors that
    /// cross-emit payloads (e.g. flowchart parses state into flowchart),
    /// which the factory's strict `unwrap` cannot express.
    static func _typed<Parsed: Sendable, Positioned: Sendable>(
        type: DiagramType,
        matches: @escaping @Sendable (DiagramHeader) -> Bool,
        parse: @escaping @Sendable (String, DiagramFrontmatter?) throws -> Parsed,
        wrap: @escaping @Sendable (Parsed) -> DiagramPayload,
        unwrap: @escaping @Sendable (DiagramPayload) -> Parsed?,
        layout: @escaping @Sendable (Parsed, LayoutConfig) throws -> Positioned,
        positioned: @escaping @Sendable (DiagramDocument, Positioned) -> PositionedGraph
    ) -> DiagramDescriptor {
        DiagramDescriptor(
            type: type,
            matches: matches,
            parse: { source, fm in
                let parsed = try parse(source, fm)
                return DiagramDocument(payload: wrap(parsed))
            },
            layout: { graph, config in
                guard let parsed = unwrap(graph.payload) else {
                    throw DiagramStructuralError.payloadMismatch(type)
                }
                return positioned(graph, try layout(parsed, config))
            }
        )
    }
}
