import DiagramKitModel

/// A source-format importer that parses text into a `DiagramDocument`.
///
/// Conformers register with `ImporterRegistry`. The registry probes each
/// importer in order; the first `supports(source:)` match wins.
///
/// ## Concurrency Contract
/// `DiagramSourceImporter` is `Sendable`. Implementations must be safe for
/// concurrent use. All parsing state (including diagnostics) is returned in
/// `DiagramImportResult` — there is no shared mutable diagnostics property.
/// This keeps importers stateless at the protocol boundary.
public protocol DiagramSourceImporter: Sendable {
    /// Human-readable name (e.g. "Mermaid", "d2", "DOT").
    var name: String { get }

    /// The set of `DiagramType` values this importer can produce.
    /// Used for UI discovery and sparse-matrix validation.
    var supportedDiagramTypes: Set<DiagramType> { get }

    /// Returns `true` when `source` appears to be in this importer's format.
    /// This is a text-only probe — it should be fast and avoid full parsing.
    /// The first importer returning `true` for a given source wins.
    ///
    /// Narrow / specific probes must return `true` only for their own format.
    /// The Mermaid importer's probe is intentionally broad and acts as the
    /// fallback — it is ordered LAST in the default registry.
    func supports(source: String) -> Bool

    /// Parse `source` into a `DiagramImportResult`.
    ///
    /// - Parameters:
    ///   - source: The raw diagram source text. The importer is responsible
    ///     for any format-specific preprocessing (XML entity decoding,
    ///     frontmatter parsing, etc.).
    /// - Returns: A `DiagramImportResult` containing the parsed document and
    ///   any non-fatal diagnostics.
    /// - Throws: `DiagramError` or a format-specific error on fatal parse
    ///   failures.
    func parse(_ source: String) throws -> DiagramImportResult
}
