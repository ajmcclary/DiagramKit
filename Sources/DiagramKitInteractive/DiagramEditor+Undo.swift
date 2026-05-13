// Phase 9: Interactive Model — Slice 9D
// Undo/redo stack via Foundation.UndoManager.

import DiagramKitModel
import DiagramKitImport
import Foundation

extension DiagramEditor {
    // MARK: - Undo grouping

    /// Begin an undo group. All mutations until `endUndoGrouping()`
    /// are undone/redone as a single unit.
    public func beginUndoGrouping() {
        undoManager.beginUndoGrouping()
    }

    /// End the current undo group.
    public func endUndoGrouping() {
        undoManager.endUndoGrouping()
    }

    // MARK: - Snapshot restore (nonthrowing — snapshots are known-good)

    /// Restore a previously-validated snapshot.
    ///
    /// Because the snapshot was captured after successful derivation
    /// and export, restoring it is infallible. This method does not
    /// use `try?` — any failure is a programming error.
    func _restoreSnapshot(
        document: DiagramDocument,
        source: String?,
        diagnostics: [DiagramDiagnostic]
    ) {
        // Register redo using current state (before restore).
        // UndoManager automatically manages redo groups during undo.
        let currentDocument = self.document
        let currentSource = self.source
        let currentDiagnostics = self.lastExportDiagnostics

        undoManager.registerUndo(withTarget: self) { editor in
            editor._restoreSnapshot(
                document: currentDocument,
                source: currentSource,
                diagnostics: currentDiagnostics
            )
        }

        _commitDocument(document)
        _commitSource(source)
        _commitDiagnostics(diagnostics)
    }
}
