import DiagramKitCommon
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
        ImporterRegistry._validateFallbackContract(importers)
        self.importers = importers
    }

    /// Enforces the fallback-importer contract documented on
    /// `DiagramSourceImporter.isFallback`: at most one fallback may be
    /// registered, and if present it must occupy the last slot. A
    /// fallback ahead of any narrower importer would short-circuit
    /// detection — its broad `supports(source:) → true` probe would
    /// claim the source before the narrower importer ever runs.
    /// Empty / fallback-free registries are allowed (third-party
    /// narrow-only registries are a legitimate use case).
    private static func _validateFallbackContract(
        _ importers: [any DiagramSourceImporter]
    ) {
        let fallbackIndices = importers.indices.filter { importers[$0].isFallback }
        precondition(
            fallbackIndices.count <= 1,
            "ImporterRegistry: at most one importer may declare isFallback = true (found \(fallbackIndices.count): \(fallbackIndices.map { importers[$0].name }))"
        )
        if let fallbackIndex = fallbackIndices.first {
            precondition(
                fallbackIndex == importers.count - 1,
                "ImporterRegistry: fallback importer '\(importers[fallbackIndex].name)' must be last (at index \(importers.count - 1)), found at index \(fallbackIndex)"
            )
        }
    }

    /// Returns a new registry with `importer` prepended (not appended).
    /// New, narrower importers should be probed before existing broader ones.
    public func prepending(_ importer: any DiagramSourceImporter) -> Self {
        ImporterRegistry(importers: [importer] + importers)
    }

    /// Returns a new registry with `importer` appended after every existing
    /// importer. Use this when the new importer is a **broader fallback**
    /// (e.g. a custom catch-all) and must be probed only after every existing
    /// importer has rejected the source. For narrower importers that need
    /// priority probing, use `prepending(_:)` instead.
    public func appending(_ importer: any DiagramSourceImporter) -> Self {
        ImporterRegistry(importers: importers + [importer])
    }

    /// The first importer whose `supports(source:)` returns `true`,
    /// or `nil` when no importer claims the source.
    public func importer(for source: String) -> (any DiagramSourceImporter)? {
        importers.first { $0.supports(source: source) }
    }

    /// The first importer in this registry whose `formatID` matches, or
    /// `nil` when none declares this format. Orthogonal to probe-based
    /// dispatch — does not call `supports(source:)`. Use this when the
    /// caller has already asserted the source format and wants typed
    /// routing instead of content-driven detection.
    public func importer(for formatID: DiagramFormatID) -> (any DiagramSourceImporter)? {
        importers.first { $0.formatID == formatID }
    }

    /// Empty registry — no importers registered.
    public static let empty = ImporterRegistry(importers: [])
}
