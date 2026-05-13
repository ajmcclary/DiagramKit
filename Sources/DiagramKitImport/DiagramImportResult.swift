import DiagramKitModel
// `DiagramDiagnostic` lives in DiagramKitCommon after Phase 4. Re-export it
// so downstream code that only `import DiagramKitImport` still sees the type
// without an extra import.
@_exported import DiagramKitCommon

/// The result of importing a diagram from a source format.
public struct DiagramImportResult: Sendable {
    /// The parsed diagram document, ready for layout.
    public let document: DiagramDocument
    /// Non-fatal diagnostics collected during import.
    public let diagnostics: [DiagramDiagnostic]

    public init(document: DiagramDocument, diagnostics: [DiagramDiagnostic] = []) {
        self.document = document
        self.diagnostics = diagnostics
    }
}
