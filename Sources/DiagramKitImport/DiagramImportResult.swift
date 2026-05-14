import DiagramKitCommon
import DiagramKitModel

// `DiagramDiagnostic` lives in DiagramKitCommon after Phase 4. Re-export
// just that single type so `import DiagramKitImport` still resolves
// `DiagramDiagnostic` without pulling the entire DiagramKitCommon namespace
// in transitively.
public typealias DiagramDiagnostic = DiagramKitCommon.DiagramDiagnostic

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
