// Phase 9: Interactive Model — Slice 9C
// Source sync via export protocol.

import DiagramKitModel
import DiagramKitExport
import Foundation

extension DiagramEditor {
    /// Re-export the current document via `preferredExportFormat`.
    ///
    /// Uses `DiagramExportLoader.export(_:to:registry:)` for deterministic
    /// format-ID-based dispatch. Sets `source` to the exported source text
    /// and `lastExportDiagnostics` to any non-fatal diagnostics.
    ///
    /// - Throws: `DiagramExportError` if no exporter is registered for
    ///   `preferredExportFormat`, or if the exporter throws a fatal error.
    public func syncSource() throws {
        let result = try DiagramExportLoader.export(
            document,
            to: preferredExportFormat,
            registry: exportRegistry
        )
        _commitSource(result.source)
        _commitDiagnostics(result.diagnostics)
    }

    /// Internal helper: export without mutating state.
    /// Used during atomic commit to validate before state swap.
    func _export(_ document: DiagramDocument) throws -> DiagramExportResult {
        try DiagramExportLoader.export(
            document,
            to: preferredExportFormat,
            registry: exportRegistry
        )
    }
}
