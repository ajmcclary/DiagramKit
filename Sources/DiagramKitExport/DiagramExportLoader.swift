import DiagramKitModel
import DiagramKitImport

/// Stateless dispatch: export a `DiagramDocument` to a target format.
/// The `to:` format ID is authoritative — it selects the exact exporter.
public enum DiagramExportLoader {

    /// Export `document` to the given format.
    ///
    /// - Parameters:
    ///   - document: The diagram document to export.
    ///   - to: The target format ID (e.g., `.d2`, `.plantuml`).
    ///     This is authoritative — it selects the exact exporter.
    ///   - registry: The exporter registry to search.
    /// - Returns: `DiagramExportResult` with the generated source and any
    ///   diagnostics.
    /// - Throws: `DiagramExportError` when no exporter is registered for the
    ///   format, or when the matched exporter throws a fatal error.
    public static func export(
        _ document: DiagramDocument,
        to formatID: DiagramFormatID,
        registry: ExporterRegistry
    ) throws -> DiagramExportResult {
        guard let exporter = registry.exporter(named: formatID) else {
            throw DiagramExportError(
                message: "No exporter registered for format \(formatID)",
                diagnostics: [
                    DiagramDiagnostic(
                        severity: .unsupported,
                        message: "Format '\(formatID)' has no registered exporter"
                    )
                ]
            )
        }

        // If the exporter doesn't support this diagram type, return a
        // diagnostic — never throw for unsupported types.
        guard exporter.supportedDiagramTypes.contains(document.type) else {
            return DiagramExportResult(
                source: "",
                diagnostics: [
                    DiagramDiagnostic(
                        severity: .unsupported,
                        message: "Diagram type '\(document.type.rawValue)' is not supported for export to '\(formatID)'"
                    )
                ]
            )
        }

        return try exporter.export(document)
    }

    /// Convenience: export using a specific exporter by display name.
    /// Prefer `export(_:to:registry:)` with a format ID for type safety.
    public static func export(
        _ document: DiagramDocument,
        using exporterName: String,
        registry: ExporterRegistry
    ) throws -> DiagramExportResult {
        guard let exporter = registry.exporters.first(where: { $0.name == exporterName }) else {
            throw DiagramExportError(
                message: "No exporter named '\(exporterName)' in registry"
            )
        }

        guard exporter.supportedDiagramTypes.contains(document.type) else {
            return DiagramExportResult(
                source: "",
                diagnostics: [
                    DiagramDiagnostic(
                        severity: .unsupported,
                        message: "Diagram type '\(document.type.rawValue)' is not supported by exporter '\(exporterName)'"
                    )
                ]
            )
        }

        return try exporter.export(document)
    }
}
