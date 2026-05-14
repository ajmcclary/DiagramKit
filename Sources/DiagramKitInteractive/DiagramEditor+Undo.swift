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
    ///
    /// Selection is captured along with document/source/diagnostics so
    /// `.deleteElement(selection)` followed by undo restores the
    /// pre-delete selection rather than leaving a dangling reference to
    /// a non-existent element (which would throw `.elementNotFound` on
    /// the next mutation).
    func _restoreSnapshot(
        document: DiagramDocument,
        source: String?,
        diagnostics: [DiagramDiagnostic],
        selection: DiagramSelection?
    ) {
        // Register redo using current state (before restore).
        // UndoManager automatically manages redo groups during undo.
        let currentDocument = self.document
        let currentSource = self.source
        let currentDiagnostics = self.lastExportDiagnostics
        let currentSelection = self.selection

        undoManager.registerUndo(withTarget: self) { editor in
            editor._restoreSnapshot(
                document: currentDocument,
                source: currentSource,
                diagnostics: currentDiagnostics,
                selection: currentSelection
            )
        }

        _commitDocument(document)
        _commitSource(source)
        _commitDiagnostics(diagnostics)
        self.selection = selection
    }
}
