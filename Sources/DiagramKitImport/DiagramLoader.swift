import DiagramKitModel

/// Stateless dispatch: probe an `ImporterRegistry` and parse through the
/// first matching importer.
public enum DiagramLoader {

    /// Parse `source` using the given registry.
    ///
    /// Probes each importer in the registry in order; the first
    /// `supports(source:) → true` wins. Returns the parsed `DiagramImportResult`
    /// containing the `DiagramDocument` and any diagnostics.
    ///
    /// - Parameters:
    ///   - source: Raw diagram source text.
    ///   - registry: The importer registry to probe.
    /// - Returns: `DiagramImportResult` with the parsed document and diagnostics.
    /// - Throws: `DiagramError` on fatal parse failures. Throws a loader-level
    ///   error when no importer claims the source.
    public static func parse(
        _ source: String,
        registry: ImporterRegistry
    ) throws -> DiagramImportResult {
        guard let importer = registry.importer(for: source) else {
            // Distinguish "no importer claimed the source" from
            // "implementation gap inside an importer" by routing through
            // `.unrecognizedFormat`.
            let preview = source.prefix(40).trimmingCharacters(in: .whitespacesAndNewlines)
            throw DiagramError.unrecognizedFormat(
                preview.isEmpty
                    ? "source is empty or whitespace-only"
                    : "no importer matched: \"\(preview)…\""
            )
        }
        return try importer.parse(source)
    }

    /// Shorthand returning only the `DiagramDocument`, discarding diagnostics.
    public static func parseDocument(
        _ source: String,
        registry: ImporterRegistry
    ) throws -> DiagramDocument {
        try parse(source, registry: registry).document
    }
}
