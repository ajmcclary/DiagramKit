// Apple-only (UndoManager, Observation editor model) gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Phase 9: Interactive Model — Slice 9B
// Core DiagramEditor class.

import DiagramKitCommon
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
    ///
    /// Prefer the editor's async `undo()` / `redo()`, which queue behind
    /// the in-flight mutation chain. Direct `undoManager.undo()` /
    /// `.redo()` calls are only safe while `isExporting == false` —
    /// mid-export they commit state derived from a stale document.
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

    /// True while at least one async mutation is in flight on this
    /// editor. Driven by the chained-Task pattern in `perform` and
    /// `performFlowchart`; flips on the 0→1 transition of
    /// `_mutationDepth` and back on the N→0 transition.
    ///
    /// SwiftUI hosts can read this to disable mutation buttons:
    /// `.disabled(editor.isExporting)`.
    public private(set) var isExporting: Bool = false

    /// Most-recently-started in-flight mutation Task. Used to chain
    /// the next caller behind the previous task so commits land in
    /// registration order.
    @ObservationIgnored
    private var _pendingMutation: Task<Void, Error>?

    /// Monotonic generation paired with `_pendingMutation`. Each call
    /// to `_setPendingMutation` bumps this; the caller captures the
    /// value at set-time and uses `_clearPendingMutationIfCurrent` on
    /// exit so only the *latest* caller actually nils `_pendingMutation`.
    @ObservationIgnored
    private var _pendingMutationGeneration: UInt64 = 0

    /// Refcount of `perform`/`performFlowchart` callers currently on
    /// the chain. `isExporting` flips on transitions 0→1 and N→0.
    @ObservationIgnored
    private var _mutationDepth: Int = 0

    // MARK: - Observation-tracked undo state

    /// Tickle counter bumped by NotificationCenter observers when the
    /// undo/redo stack changes state. Reading this counter inside the
    /// computed properties below registers an `@Observable` dependency
    /// so SwiftUI modifiers like `.disabled(!editor.canUndo)` re-evaluate.
    ///
    /// `Foundation.UndoManager` is not Observation-tracked itself, so this
    /// counter is the bridge. This property is intentionally NOT
    /// `@ObservationIgnored` — the macro must instrument it so mutations
    /// fire change notifications.
    private var _undoStateTickle: UInt64 = 0

    /// Notification observer tokens. Held so `deinit` can release them.
    @ObservationIgnored
    private var _undoObservers: [NSObjectProtocol] = []

    /// True when at least one undoable action is registered.
    /// Observation-tracked; updates as the undo stack changes.
    ///
    /// Gated to `false` while `isExporting`: an undo committed during an
    /// in-flight export would be clobbered by that export's commit
    /// (which is derived from the pre-undo document). SwiftUI hosts get
    /// the gate for free via `.disabled(!editor.canUndo)`; callers that
    /// must undo mid-export should `await editor.undo()`, which queues
    /// the action until the chain drains instead of dropping it.
    public var canUndo: Bool {
        _ = _undoStateTickle
        return !isExporting && undoManager.canUndo
    }

    /// True when at least one redoable action is registered.
    /// Observation-tracked; updates as the redo stack changes.
    /// Gated to `false` while `isExporting` — see `canUndo`.
    public var canRedo: Bool {
        _ = _undoStateTickle
        return !isExporting && undoManager.canRedo
    }

    /// Display name of the action that `undo()` would reverse, or `""`
    /// when no undo is available. Use for menu item / button labels.
    public var undoActionName: String {
        _ = _undoStateTickle
        return undoManager.undoActionName
    }

    /// Display name of the action that `redo()` would re-apply, or `""`
    /// when no redo is available.
    public var redoActionName: String {
        _ = _undoStateTickle
        return undoManager.redoActionName
    }

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
        _registerUndoObservers()
    }

    /// Subscribe to the four `UndoManager` notifications that gate
    /// undo/redo state transitions. Observers are scoped to this
    /// editor's `undoManager` via the `object:` parameter so two
    /// `DiagramEditor` instances never cross-tickle.
    ///
    /// Each observer increments `_undoStateTickle`, which is read inside
    /// the four `canUndo` / `canRedo` / `undoActionName` /
    /// `redoActionName` computed properties — that's the bridge into
    /// the `@Observable` change-tracking system.
    private func _registerUndoObservers() {
        let names: [Notification.Name] = [
            .NSUndoManagerDidUndoChange,
            .NSUndoManagerDidRedoChange,
            .NSUndoManagerDidCloseUndoGroup,
            .NSUndoManagerCheckpoint
        ]
        for name in names {
            // `queue: nil` delivers synchronously on the posting thread.
            // Almost all `UndoManager` state changes we care about happen
            // on MainActor (mutations + direct .undo()/.redo() calls
            // from UI code), and synchronous delivery on that path keeps
            // Observation tracking deterministic for tests — the tickle
            // fires before `await perform(_:)` returns.
            //
            // `UndoManager` is documented thread-safe but not typed
            // `@MainActor`, so we cannot assume the post site. If a
            // notification arrives off-main, a bare `MainActor
            // .assumeIsolated` would trip its precondition and abort the
            // process; gate it on `Thread.isMainThread` and otherwise
            // schedule the tickle on MainActor.
            let token = NotificationCenter.default.addObserver(
                forName: name,
                object: undoManager,
                queue: nil
            ) { [weak self] _ in
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        self?._undoStateTickle &+= 1
                    }
                } else {
                    Task { @MainActor [weak self] in
                        self?._undoStateTickle &+= 1
                    }
                }
            }
            _undoObservers.append(token)
        }
    }

    isolated deinit {
        // `isolated deinit` keeps `@MainActor` isolation through teardown
        // so the array of observer tokens — which is not Sendable —
        // remains accessible. `NotificationCenter.removeObserver(_:)` is
        // safe to call from MainActor.
        for token in _undoObservers {
            NotificationCenter.default.removeObserver(token)
        }
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

    // MARK: - Async mutation chain helpers

    /// Increment the in-flight refcount. Flips `isExporting` to `true`
    /// on the 0→1 transition.
    func _enterMutationChain() {
        _mutationDepth += 1
        if _mutationDepth == 1 { isExporting = true }
    }

    /// Decrement the in-flight refcount. Flips `isExporting` to `false`
    /// on the N→0 transition.
    func _exitMutationChain() {
        _mutationDepth -= 1
        if _mutationDepth == 0 { isExporting = false }
    }

    /// Enqueue `body` as the next task on this editor's mutation chain
    /// and await its completion.
    ///
    /// The chain is formed *inside* the task: installation of the new
    /// task happens synchronously here on the MainActor — before this
    /// caller suspends — and the task first awaits the previously
    /// installed task before running `body`. Two callers enqueued while
    /// task P is in flight therefore run strictly in install order
    /// (P → A → B), and B can never observe pre-A state. (The earlier
    /// `_awaitPendingMutation` shape awaited the captured pending task
    /// in the *caller*, so A and B raced to install after P and B
    /// committed a document derived from pre-A state, silently dropping
    /// A's mutation.)
    ///
    /// Errors from earlier chain tasks are absorbed (a failed mutation
    /// does not stop later ones); `body`'s own error propagates to this
    /// caller. The task is unstructured, so cancelling the caller does
    /// not abort an in-flight commit.
    ///
    /// - Parameter body: Runs on the MainActor with the editor passed
    ///   back in; the `[weak self]` capture in the task means the body
    ///   never runs against a deallocated editor.
    func _enqueueChainedMutation(
        _ body: @escaping @MainActor @Sendable (DiagramEditor) async throws -> Void
    ) async throws {
        _enterMutationChain()
        defer { _exitMutationChain() }

        let previous = _pendingMutation
        let task = Task { @MainActor [weak self] in
            if let previous {
                _ = try? await previous.value
            }
            guard let self else { return }
            try await body(self)
        }
        let generation = _setPendingMutation(task)
        defer { _clearPendingMutationIfCurrent(generation: generation) }

        try await task.value
    }

    /// Wait until the mutation chain has fully drained — no pending
    /// mutation task remains. Used by `undo()`/`redo()` so a user undo
    /// issued while an async mutation is mid-export applies strictly
    /// after that commit instead of racing it. Errors are absorbed:
    /// draining only cares about ordering.
    ///
    /// The `Task.yield()` between iterations is load-bearing: awaiting
    /// an already-completed task's `value` can return without
    /// suspending, so re-reading `_pendingMutation` before its owning
    /// caller's deferred `_clearPendingMutationIfCurrent` has run would
    /// re-await the same task in a tight loop and starve the MainActor.
    /// The yield hands the executor to that caller so the slot clears.
    func _awaitChainDrain() async {
        while true {
            guard let pending = _pendingMutation else { return }
            _ = try? await pending.value
            await Task.yield()
        }
    }

    /// Record `task` as the new pending mutation and return the
    /// generation token. Callers pass the token to
    /// `_clearPendingMutationIfCurrent(generation:)` on exit.
    func _setPendingMutation(_ task: Task<Void, Error>) -> UInt64 {
        _pendingMutationGeneration &+= 1
        _pendingMutation = task
        return _pendingMutationGeneration
    }

    /// Clear `_pendingMutation` only if the generation token matches
    /// the current one — i.e., only the latest caller actually nils it.
    func _clearPendingMutationIfCurrent(generation: UInt64) {
        if _pendingMutationGeneration == generation {
            _pendingMutation = nil
        }
    }
}
#endif
