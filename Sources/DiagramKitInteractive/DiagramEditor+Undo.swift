// Apple-only (UndoManager, Observation editor model) gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Phase 9: Interactive Model — Slice 9D
// Undo/redo stack via Foundation.UndoManager.

import DiagramKitModel
import DiagramKitImport
import Foundation

extension DiagramEditor {
    // MARK: - Queued undo/redo

    /// Undo the last committed mutation, waiting for any in-flight
    /// mutation chain to drain first.
    ///
    /// H2 related fix: an undo issued while an async mutation was
    /// mid-export used to restore a snapshot immediately and then be
    /// clobbered by that export's commit — a stale document derived from
    /// the pre-undo state, plus an incoherent redo entry.
    ///
    /// Queueing until the chain drains is chosen over re-validating a
    /// document version at commit time because it can neither drop the
    /// user's undo action (the undo always applies, only later) nor
    /// commit stale state (the undo runs strictly after the in-flight
    /// commit, so `_restoreSnapshot`'s redo registration captures the
    /// post-commit document). The drain loop re-reads `_pendingMutation`
    /// on the MainActor, and once it observes nil there is no suspension
    /// before `undoManager.undo()` runs, so no mutation can interleave
    /// between drain and undo.
    public func undo() async {
        await _awaitChainDrain()
        undoManager.undo()
    }

    /// Redo the most recently undone mutation. Same queue-until-drained
    /// contract as `undo()` — see there for the rationale.
    public func redo() async {
        await _awaitChainDrain()
        undoManager.redo()
    }

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
#endif
