# Async Export Off MainActor — Design

**Status:** draft
**Date:** 2026-05-14
**Tracks:** REVIEW.md Deferred Effort §4 → Playground state machine →
"`_export` runs synchronously on `@MainActor`; large flowcharts block main.
Hop to a worker for the export call."

## Problem

`DiagramEditor` is `@MainActor @Observable` and exposes synchronous `throws`
mutation entry points (`perform(_:)`, `performFlowchart(_:)`,
`syncSource()`). Each mutation runs three steps on the main thread:

1. **Derivation** — `_apply(mutation, to: document)`: in-memory document
   transform. Cheap.
2. **Export** — `_export(newDocument)`: serializes the new document through
   `DiagramExportLoader.export(...)` to validate round-trip and obtain the
   new `source` string. **Potentially expensive** for large flowcharts —
   runs every Mermaid/D2/PlantUML emit pass, sanitizer, walker.
3. **Commit** — swap state, register undo. Cheap.

Step 2 blocks `MainActor` synchronously. On large diagrams this stutters
the UI; on `LiveEditorStore.performMutation` (the playground call site)
it pins the run loop for the duration of the export.

CLAUDE.md's "no thread pool, every public entry point dispatches to a
fresh 8 MB worker" rule applies — we already meet it in `DiagramEngine`
via `DiagramWorkerThread.run`, but `DiagramEditor` skips the worker
entirely.

The contract today is **atomic** — derivation + export must both succeed
before any state changes. We preserve that contract; we just stop running
step 2 on `MainActor`.

## Goals

- Move `DiagramExportLoader.export` off `MainActor` for every mutation
  path in `DiagramEditor`.
- Keep the atomic commit contract: a failing export leaves all state
  untouched.
- Serialize concurrent mutations so each one gets an undo entry and
  commits in caller-registration order.
- Expose a single observable signal (`isExporting`) so SwiftUI hosts can
  disable mutation buttons and avoid piling up Tasks.
- Preserve CLAUDE.md's "fresh 8 MB worker thread per dispatch" rule by
  reusing `DiagramWorkerThread`.

## Non-goals

- **Async parse / async render pipeline changes.**
  `DiagramEngine.parse/renderImage/renderSVG/renderASCII` are already
  async — no work needed there.
- **Linux SVG/ASCII parity.** The `#if canImport(CoreGraphics)` gating
  on `DiagramEngine.renderSVG/renderASCII` is a separate deferred item
  (REVIEW.md Critical → Public API contract holes). This spec only
  touches `DiagramKitInteractive`, which is Apple-only by design.
- **`DiagramExportLoader.export` itself.** No signature change at the
  loader level. The worker hop happens *above* it in `DiagramEditor`.
  This keeps `DiagramKitExport` Linux-portable and untangles its API
  from the editor's concurrency story.
- **Cancellation that aborts in-flight worker exports.** The
  fresh-Thread worker pattern (`DiagramWorkerThread.run`) runs to
  completion by design — no `Task.checkCancellation` hooks inside the
  exporters. Cancellation isolation (see "Internals") is the most we
  offer.
- **Optimistic UI.** Document does not change until export succeeds.
  Same atomic contract as today.
- **Coalesce / debounce.** UI disables the buttons during `isExporting`;
  no need to drop or merge mutations at the editor layer.
- **Moving `lastMutationError` onto `DiagramEditor`.** Stays at
  `LiveEditorStore`. Editor remains pure mutation-engine; playground
  owns playground-shaped state.

## Public API

Three methods change signature; one observable property is added. No
deprecated sync wrapper.

### Changed

- `public func perform(_ mutation: DiagramMutation) throws`
  → `public func perform(_ mutation: DiagramMutation) async throws`
- `public func performFlowchart(_ mutation: FlowchartMutation) throws`
  → `public func performFlowchart(_ mutation: FlowchartMutation) async throws`
- `public func syncSource() throws`
  → `public func syncSource() async throws`

### Added

- `public private(set) var isExporting: Bool` — `false` when no
  mutation is in flight, `true` while the worker hop is outstanding.
  Backed by `@Observable` tracking so SwiftUI views can read it
  reactively (e.g. `.disabled(editor.isExporting)`).

### Unchanged

- `_restoreSnapshot(...)` (undo callback) stays sync — pure in-memory
  state swap. Undo/redo does not re-export.
- `document`, `source`, `selection`, `lastExportDiagnostics`,
  `undoManager`, `preferredExportFormat`, `maximumUndoDepth` — all
  `@MainActor`, no change.
- Atomic-commit contract: if the worker throws, no state changes; the
  error surfaces to the caller as
  `DiagramEditorError.sourceSyncFailed(underlying:)`.

### Caller-side migration

- `LiveEditorStore.performMutation` and `performFlowchartMutation`:
  `throws` → `async throws`. They already call `try editor.perform(...)`;
  just add `await`.
- `DiagramEditorPane` button actions: wrap calls in
  `Task { try? await store.performMutation(...) }`.
  `.disabled(store.editor?.isExporting == true)` on mutation buttons.
- Tests: every callsite of `editor.perform`, `editor.performFlowchart`,
  `editor.syncSource` gains `try await` and its enclosing test function
  becomes `async`. Scope identified during implementation by
  `grep -rn "editor\.perform\|editor\.syncSource" Tests/`.

## Internals

### Worker hop

A new internal helper replaces the synchronous `_export`:

```swift
// Sources/DiagramKitInteractive/DiagramEditor+SourceSync.swift
func _exportAsync(_ document: DiagramDocument) async throws
    -> DiagramExportResult
{
    let format = preferredExportFormat
    let registry = exportRegistry
    return try await DiagramWorkerThread.run {
        try DiagramExportLoader.export(
            document, to: format, registry: registry
        )
    }
}
```

`DiagramWorkerThread` lives in `DiagramKitRenderingCG`, which
`DiagramKitInteractive` does **not** currently depend on. The plan
adds it as an **Apple-conditional** target dependency in `Package.swift`,
mirroring the existing umbrella → Interactive edge (lines 153–155 today):

```swift
.target(
    name: "DiagramKitInteractive",
    dependencies: [
        "DiagramKitCommon", "DiagramKitModel",
        "DiagramKitImport", "DiagramKitExport",
        .target(
            name: "DiagramKitRenderingCG",
            condition: .when(platforms: [
                .macOS, .iOS, .tvOS, .visionOS, .macCatalyst
            ])
        )
    ],
    swiftSettings: strictConcurrencySettings
),
```

On Linux, `Interactive` falls back to a private fresh-`Thread` helper
that mirrors `DiagramEngine._runOnWorker`'s Linux branch and uses
`DiagramWorkerConfig.stackSize` from `DiagramKitCommon` (already
Linux-portable). `Dockerfile.linux-check` does not explicitly build
`DiagramKitInteractive` today, so this change does not affect the
existing Linux gate — but the Linux fallback is still wired so the
target builds on Linux if a downstream consumer imports it.

`DiagramDocument`, `DiagramFormatID`, and `ExporterRegistry` are
`Sendable` (verified during plan phase). The closure captures by value.

The synchronous `_export` is replaced wholesale: deleted in the same
commit that introduces `_exportAsync`. No deprecated internal stub
remains. The migration is in-tree only — `_export` was not part of any
public API surface, so the change has no consumer impact beyond the
editor's own extensions and tests.

### Serialization

Swift `await` releases `MainActor` re-entrancy, so two `perform()` calls
firing rapidly could overlap. We force ordering with a chained-task
pattern stored on the editor:

```swift
// On DiagramEditor (internal):
private var pendingMutation: Task<Void, Error>?
private var mutationDepth: Int = 0

public func perform(_ mutation: DiagramMutation) async throws {
    mutationDepth += 1
    if mutationDepth == 1 { isExporting = true }
    defer {
        mutationDepth -= 1
        if mutationDepth == 0 { isExporting = false }
    }

    // Wait for any in-flight mutation to fully commit (or fail).
    if let pending = pendingMutation {
        _ = try? await pending.value
    }

    let task = Task { @MainActor [weak self] in
        guard let self else { return }
        try await self._performInner(mutation)
    }
    pendingMutation = task
    defer {
        if pendingMutation === task { pendingMutation = nil }
    }
    try await task.value
}
```

The check-and-store between `pendingMutation` read, `Task` creation,
and `pendingMutation` write is atomic on `MainActor` (no `await`
between them). Each caller's `await task.value` chains behind the
previous task. The chain is shallow because UI disables buttons during
`isExporting`; in tests it can grow but is bounded by test setup.

**Why a refcount for `isExporting`.** A single `defer { isExporting =
false }` would briefly flicker false between caller A's resumption
(continuations resume on `MainActor` one at a time) and caller B's
re-set. `mutationDepth` tracks the number of `perform` calls currently
on the chain; `isExporting` flips to `true` only on the 0→1 transition
and back to `false` only on the N→0 transition. Mid-chain entries and
exits do not write to `isExporting`, so `@Observable` does not emit
spurious change notifications.

`_performInner(_:)` does the work:

```swift
private func _performInner(_ mutation: DiagramMutation) async throws {
    let newDocument = try _apply(mutation, to: document)
    let exportResult: DiagramExportResult
    do {
        exportResult = try await _exportAsync(newDocument)
    } catch {
        throw DiagramEditorError.sourceSyncFailed(
            underlying: error.localizedDescription
        )
    }
    let oldDocument = document
    let oldSource = source
    let oldDiagnostics = lastExportDiagnostics
    let oldSelection = selection
    _commitDocument(newDocument)
    _commitSource(exportResult.source)
    _commitDiagnostics(exportResult.diagnostics)
    undoManager.registerUndo(withTarget: self) { editor in
        editor._restoreSnapshot(
            document: oldDocument,
            source: oldSource,
            diagnostics: oldDiagnostics,
            selection: oldSelection
        )
    }
    undoManager.setActionName(mutation.undoActionName)
}
```

This mirrors the existing three-step commit; only the export call
becomes `await`. `performFlowchart(_:)` uses the same shape with its
own `_performFlowchartInner`.

### Failure semantics

If `_exportAsync` throws, `_performInner` re-throws as
`DiagramEditorError.sourceSyncFailed(underlying:)` *before* the commit
block runs. State is untouched. Same as today. The chain-task pattern
propagates the throw through `task.value` to the caller.

### Cancellation semantics

Cancellation of a caller's outer `Task` only stops *that caller* from
waiting on `task.value`. The inner `Task` (and the
`DiagramWorkerThread.run` it kicks off) runs to completion regardless.
Once the inner task completes, the chained next caller's
`try? await pending.value` returns and that caller proceeds normally.

This means atomicity is preserved across cancellation, and the editor
never enters a half-committed state from a torn cancel.

### Observability

`DiagramEditor.isExporting` is the single source of truth for "a
mutation is in flight." It transitions `true` exactly when
`pendingMutation` becomes non-nil and `false` when it clears. Both
transitions happen on `MainActor` between sync statements — no torn
reads.

The playground does not need its own `isExporting`. Views read
`store.editor?.isExporting ?? false` directly. The `@Observable` macro
on `DiagramEditor` makes this reactive.

`lastMutationError` stays on `LiveEditorStore` — it's playground state,
not editor state.

### Snapshot/undo timing

Today's `LiveEditorStore` already snapshots `pendingRenderState` at
request and promotes at completion (commit `92c53b1`). The async export
commit fits the same model: `_performInner` writes the new state inside
its own `MainActor` body, after which the existing `requestRender` flow
re-parses and the snapshot promotion takes effect. No new render-
pipeline coupling.

## Test plan

### Updated tests

Every existing callsite of `editor.perform`, `editor.performFlowchart`,
or `editor.syncSource` gains `try await`. The enclosing `@Test` /
`func test…()` becomes `async`. Both swift-testing and XCTest support
async test functions — no scaffolding needed.

### New tests

Add `Tests/DiagramKitTests/DiagramEditorAsyncExportTests.swift`:

- **Atomicity** — a deliberate exporter error leaves `document`,
  `source`, and `undoManager` untouched. Use a custom test exporter
  that throws on call.
- **Serialization** — two `Task { try await editor.perform(.setLabel(…)) }`
  calls firing without intermediate awaits commit in registration
  order. Verify by checking the final `source` and undo stack depth
  (`editor.undoManager.canUndo == true`, two `undo()` calls restore
  through both mutations to the initial document).
- **`isExporting` transitions** — starts `false`, becomes `true` during
  the worker hop, returns to `false` after commit. Use a custom
  test-only exporter that blocks on a continuation to observe the
  `true` window.
- **Cancellation isolation** — cancelling the outer `Task` does not
  abort the in-flight commit. After the cancelled await returns,
  `document` reflects the commit.

Add `Tests/DiagramKitTests/DiagramEditorWorkerThreadTests.swift`:

- **Off MainActor** — assert `Thread.isMainThread == false` inside the
  test exporter's `export` callback, proving the worker hop fires.

### Verification gates

- `swift test --filter DiagramEditor` — covers existing + new editor
  tests.
- `swift test --filter LiveEditorStore` if any such suite exists.
- `Scripts/check-sendable-annotations.sh` — `DiagramEditor` gains a
  `Task<Void, Error>?` field; verify no `@unchecked Sendable` needed
  (the editor is `@MainActor`-isolated, so the field is actor-isolated,
  not Sendable-checked).
- `Scripts/strict-concurrency-check.sh` — must stay clean. The closure
  passed to `DiagramWorkerThread.run` is `@Sendable`; capture list
  verified.
- `swift run DiagramPlayground` — manual smoke: perform a `setLabel` on
  a large flowchart, observe button disables during export, verify
  undo restores.

### Snapshot impact

None. Renderer output is unchanged — only the threading of
`DiagramExportLoader.export` moves. No baseline regeneration needed.

## Risks

- **Test churn** — every `editor.perform` callsite needs `await`. Risk
  is volume, not difficulty; mitigated by `grep` sweep during
  implementation.
- **Capture-list correctness** — `[weak self]` inside the chained Task
  must not over-capture. Reviewed in the implementation plan.
- **Strict concurrency** — `Task { @MainActor [weak self] in … }`
  patterns occasionally trip Swift 6 mode. Verify with
  `Scripts/strict-concurrency-check.sh` before merging.
- **UndoManager threading** — `UndoManager.registerUndo(withTarget:)`
  is documented main-thread-only. We stay on `MainActor` for the
  commit block, so this is preserved.

## Acceptance

- `DiagramEditor.perform / performFlowchart / syncSource` are `async
  throws`. No sync wrappers remain.
- `DiagramExportLoader.export` is invoked from `DiagramWorkerThread.run`
  on every mutation path; never from `MainActor`.
- Atomic-commit contract preserved: exporter throw → no state change.
- Mutations fired from the same call site in rapid succession commit
  in registration order and each gets an undo entry.
- `editor.isExporting` toggles `true` for the duration of the worker
  hop and is `@Observable`-tracked.
- New test suites green under `swift test --filter DiagramEditor`.
- `Scripts/check-sendable-annotations.sh` and
  `Scripts/strict-concurrency-check.sh` green.
- Playground manual smoke: mutation buttons disable during export on a
  large flowchart; UI remains responsive (no run-loop pin).
