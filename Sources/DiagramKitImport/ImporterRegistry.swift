import DiagramKitModel

/// An ordered collection of source-format importers.
///
/// Detection is first-match-wins: when `DiagramLoader` probes each importer
/// in array order, the first `supports(source:) → true` wins.
/// **Probe order is contractual** — it is enforced by `ProbeCollisionMatrixTests`.
///
/// Specific/narrow importers (d2, DOT, PlantUML, Structurizr) must be ordered
/// BEFORE the broad Mermaid fallback importer. Mermaid's probe intentionally
/// returns `true` for any source, so it MUST be last in the registry.
public struct ImporterRegistry: Sendable {
    public let importers: [any DiagramSourceImporter]

    public init(importers: [any DiagramSourceImporter]) {
        self.importers = importers
    }

    /// Returns a new registry with `importer` prepended (not appended).
    /// New, narrower importers should be probed before existing broader ones.
    public func prepending(_ importer: any DiagramSourceImporter) -> Self {
        ImporterRegistry(importers: [importer] + importers)
    }

    /// The first importer whose `supports(source:)` returns `true`,
    /// or `nil` when no importer claims the source.
    public func importer(for source: String) -> (any DiagramSourceImporter)? {
        importers.first { $0.supports(source: source) }
    }

    /// Empty registry — no importers registered.
    public static let empty = ImporterRegistry(importers: [])
}
