import DiagramKitModel
import DiagramKitImport

/// A format exporter that emits source text from a `DiagramDocument`.
///
/// Conformers register with `ExporterRegistry`. Each exporter declares the
/// set of `DiagramType` values it can export.
///
/// ## Concurrency Contract
/// `DiagramExporter` is `Sendable`. Implementations must be safe for
/// concurrent use. All state (including diagnostics) is returned in
/// `DiagramExportResult` — there is no shared mutable diagnostics property.
/// This keeps exporters stateless at the protocol boundary.
public protocol DiagramExporter: Sendable {
    /// Human-readable display name (e.g. "Mermaid", "D2", "PlantUML").
    /// For registry lookup, use `formatID` instead.
    var name: String { get }

    /// Canonical format identifier. Used by `ExporterRegistry` and
    /// `DiagramExportLoader` for format-targeted dispatch.
    var formatID: DiagramFormatID { get }

    /// The set of `DiagramType` values this exporter can emit as source.
    /// Must be a subset of the corresponding importer's `supportedDiagramTypes`.
    var supportedDiagramTypes: Set<DiagramType> { get }

    /// Emit source text for the given diagram document.
    ///
    /// - Parameter document: The diagram document to export.
    /// - Returns: A `DiagramExportResult` containing the source string and
    ///   any non-fatal diagnostics (e.g., dropped styling, unsupported
    ///   sub-features).
    /// - Throws: `DiagramExportError` on fatal export failures (e.g.,
    ///   impossible model state).
    ///
    /// When `document.type` is not in `supportedDiagramTypes`, the exporter
    /// returns a result with an empty source and a `.unsupported` diagnostic.
    func export(_ document: DiagramDocument) throws -> DiagramExportResult
}
