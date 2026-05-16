import DiagramKitCommon
import DiagramKitModel

/// The result of exporting a `DiagramDocument` to a source format.
public struct DiagramExportResult: Sendable {
    /// The generated source text. Empty when the diagram type is not
    /// supported by the exporter. An empty source MUST be accompanied by
    /// at least one diagnostic.
    public let source: String

    /// Non-fatal diagnostics collected during export.
    public let diagnostics: [DiagramDiagnostic]

    public init(source: String, diagnostics: [DiagramDiagnostic] = []) {
        self.source = source
        self.diagnostics = diagnostics
    }
}

extension DiagramExportResult {
    /// Canonical "diagram family unsupported" result for exporters that do
    /// not implement the given diagram type. Returns an empty source string
    /// and a single `featureDropped(.diagramFamilyUnsupported)` diagnostic
    /// with the wording `"<formatName> export for '<type>' is not supported"`.
    ///
    /// Callers pass the human-readable format name they expose via
    /// `DiagramExporter.name` (e.g. "D2", "Graphviz") so diagnostic wording
    /// stays consistent across formats. Closes audit D4.
    public static func unsupportedDiagram(
        formatName: String,
        type: DiagramType
    ) -> DiagramExportResult {
        DiagramExportResult(
            source: "",
            diagnostics: [
                .featureDropped(
                    .diagramFamilyUnsupported,
                    message: "\(formatName) export for '\(type.rawValue)' is not supported"
                )
            ]
        )
    }
}
