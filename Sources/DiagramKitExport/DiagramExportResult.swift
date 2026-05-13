import DiagramKitCommon

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
