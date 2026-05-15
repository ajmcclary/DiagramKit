import DiagramKitCommon
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
    public static func parseImportResult(
        _ source: String,
        registry: ImporterRegistry
    ) throws -> DiagramImportResult {
        guard let importer = registry.importer(for: source) else {
            let preview = source.prefix(40).trimmingCharacters(in: .whitespacesAndNewlines)
            throw DiagramError.unrecognizedFormat(
                preview.isEmpty
                    ? "source is empty or whitespace-only"
                    : "no importer matched: \"\(preview)…\""
            )
        }
        return try withImporterFormat(importer.parse(source), importer: importer)
    }

    /// Alias for `parseImportResult(_:registry:)` retained for callers that
    /// adopted the original name.
    public static func parse(
        _ source: String,
        registry: ImporterRegistry
    ) throws -> DiagramImportResult {
        try parseImportResult(source, registry: registry)
    }

    /// Shorthand returning only the `DiagramDocument`, discarding diagnostics.
    public static func parseDocument(
        _ source: String,
        registry: ImporterRegistry
    ) throws -> DiagramDocument {
        try parseImportResult(source, registry: registry).document
    }

    /// Parse `source` using the importer registered under `formatID`.
    /// Bypasses content-driven probing — the caller has asserted the
    /// format. If no importer in the registry declares this format,
    /// throws `DiagramError.unrecognizedFormat`.
    ///
    /// - Parameters:
    ///   - source: Raw diagram source text.
    ///   - formatID: The format to route through.
    ///   - registry: The importer registry to search.
    /// - Returns: `DiagramImportResult` with the parsed document and diagnostics.
    /// - Throws: `DiagramError.unrecognizedFormat` when no importer in the
    ///   registry declares `formatID`; otherwise whatever the matched
    ///   importer's `parse(_:)` throws on malformed input.
    public static func parse(
        _ source: String,
        as formatID: DiagramFormatID,
        registry: ImporterRegistry
    ) throws -> DiagramImportResult {
        guard let importer = registry.importer(for: formatID) else {
            throw DiagramError.unrecognizedFormat(
                "no importer registered for format '\(formatID.rawValue)' in registry"
            )
        }
        return try withImporterFormat(importer.parse(source), importer: importer)
    }

    /// Shorthand returning only the `DiagramDocument`, discarding diagnostics.
    public static func parseDocument(
        _ source: String,
        as formatID: DiagramFormatID,
        registry: ImporterRegistry
    ) throws -> DiagramDocument {
        try parse(source, as: formatID, registry: registry).document
    }

    private static func withImporterFormat(
        _ result: DiagramImportResult,
        importer: any DiagramSourceImporter
    ) -> DiagramImportResult {
        guard result.formatID == nil else { return result }
        return DiagramImportResult(
            document: result.document,
            diagnostics: result.diagnostics,
            formatID: importer.formatID
        )
    }
}
