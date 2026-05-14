// Phase 9: Interactive Model — Slice 9B
// Core DiagramEditor class.

import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
import Observation
import Foundation

/// A `@MainActor @Observable` editor model for a single DiagramKit diagram.
///
/// Owns a `DiagramDocument`, undo/redo stack, current selection, and a
/// preferred export format for source sync. Mutations are applied through
/// `perform(_:)` and commit atomically: the new document and source are
/// validated before any state changes.
///
/// ## Concurrency Contract
/// `DiagramEditor` is `@MainActor` because it owns mutable UI-thread
/// state (selection, undo stack). The underlying `DiagramDocument`
/// is `Sendable` and can be read from any context; mutations are
/// serialized through the main actor.
///
/// This type intentionally does not conform to `Sendable`. Consumers
/// that need to serialize editor operations should use the actor
/// isolation already provided by `@MainActor`.
///
/// ## Mutation Contract
/// The `document`, `source`, and `lastExportDiagnostics` properties have
/// public setters so that the `@Observable` macro can generate proper
/// observation tracking. Consumers MUST apply mutations through
/// `perform(_:)` or `performFlowchart(_:)` — never by direct property
/// assignment. Direct assignment bypasses undo/redo and source sync.
@MainActor
@Observable
public final class DiagramEditor {
    // MARK: - Stored state

    /// The current diagram document.
    /// **Mutation contract**: consumers must mutate through `perform(_:)`
    /// or `performFlowchart(_:)`, never by direct assignment. Direct
    /// assignment bypasses undo/redo and source sync.
    public private(set) var document: DiagramDocument

    /// The preferred export format for source sync.
    /// Mutations re-export through this format via `DiagramExportLoader`.
    ///
    /// Made `var` so a host can swap formats mid-edit without rebuilding
    /// the editor. Setting this does not re-export the current document
    /// — call `syncSource()` afterwards if the source string should
    /// reflect the new format immediately.
    public var preferredExportFormat: DiagramFormatID

    /// The exporter registry used for source sync.
    public let exportRegistry: ExporterRegistry

    /// The most recently synced source text, or nil if source sync
    /// has not run or the preferred format does not support the current
    /// diagram type.
    ///
    /// **Mutation contract**: consumers must mutate through `perform(_:)`
    /// or `performFlowchart(_:)`, never by direct assignment.
    public private(set) var source: String?

    /// The current selection, or nil.
    /// Set directly by the consumer (e.g., from a tap gesture →
    /// `lookup.element(at:)` → `editor.selection = ...`).
    public var selection: DiagramSelection?

    /// The undo manager backing the undo/redo stack.
    public let undoManager: UndoManager

    /// Maximum number of undo states to retain.
    public var maximumUndoDepth: Int = 50 {
        didSet { undoManager.levelsOfUndo = maximumUndoDepth }
    }

    /// Diagnostics from the last export (source sync), if any.
    ///
    /// **Mutation contract**: consumers must mutate through `perform(_:)`
    /// or `performFlowchart(_:)`, never by direct assignment.
    public private(set) var lastExportDiagnostics: [DiagramDiagnostic] = []

    // MARK: - Initialization

    /// Create an editor for the given document, preferred export format,
    /// and exporter registry.
    ///
    /// The editor does not run an initial source sync. Call
    /// `syncSource()` after initialization to populate `source`.
    public init(
        document: DiagramDocument,
        preferredExportFormat: DiagramFormatID,
        exportRegistry: ExporterRegistry
    ) {
        self.document = document
        self.preferredExportFormat = preferredExportFormat
        self.exportRegistry = exportRegistry
        self.undoManager = UndoManager()
        self.undoManager.levelsOfUndo = maximumUndoDepth
    }

    // MARK: - Internal mutation helpers

    /// Commit a new document state. Used by mutation extensions to set
    /// state after atomic validation. Bypasses `private(set)` for
    /// same-module access.
    func _commitDocument(_ newDocument: DiagramDocument) {
        document = newDocument
    }

    /// Commit a new source string.
    func _commitSource(_ newSource: String?) {
        source = newSource
    }

    /// Commit new diagnostics.
    func _commitDiagnostics(_ newDiagnostics: [DiagramDiagnostic]) {
        lastExportDiagnostics = newDiagnostics
    }
}
