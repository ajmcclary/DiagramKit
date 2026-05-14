# Async Export Off MainActor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move `DiagramExportLoader.export` off `MainActor` for every `DiagramEditor` mutation path while preserving the atomic-commit + per-mutation undo contract. SwiftUI hosts get an `isExporting` signal so they can disable mutation buttons during the worker hop.

**Architecture:** Add an Apple-conditional `DiagramKitRenderingCG` dependency to `DiagramKitInteractive` so the editor can dispatch through `DiagramWorkerThread.run` (8 MB fresh-thread rule). `perform`, `performFlowchart`, and `syncSource` become `async throws`. A chained-`Task` pattern on the editor — `pendingMutation: Task<Void, Error>?` plus a `mutationDepth: Int` refcount — forces ordering and drives the `isExporting` observable without flicker.

**Tech Stack:** Swift 6 strict-concurrency, `@MainActor` / `@Observable` / `Foundation.UndoManager`, `swift-testing` (`@Suite`/`@Test`) for new tests, existing `DiagramExportLoader` from `DiagramKitExport`, existing `DiagramWorkerThread` and `DiagramWorkerConfig` from `DiagramKitRenderingCG` and `DiagramKitCommon`.

**Spec:** `docs/superpowers/specs/2026-05-14-async-export-off-mainactor-design.md` (committed in `eed1531`, corrected in `f64abd7`).

---

## File Structure

**Modify**
- `Package.swift` — add Apple-conditional `DiagramKitRenderingCG` dep to the `DiagramKitInteractive` target.
- `Sources/DiagramKitInteractive/DiagramEditor.swift` — add `isExporting`, `pendingMutation`, `mutationDepth`.
- `Sources/DiagramKitInteractive/DiagramEditor+SourceSync.swift` — replace sync `_export` with `_exportAsync`; promote `syncSource` to `async throws`; add private `_runOnWorker` helper.
- `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift` — promote `perform` to `async throws`; factor commit body into `_performInner`.
- `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift` — promote `performFlowchart` to `async throws`; factor commit body into `_performFlowchartInner`.
- `Examples/DiagramPlayground/Models/LiveEditorStore.swift` — `performMutation` / `performFlowchartMutation` become `async throws`.
- `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift` — wrap mutation-button taps in `Task`; add `.disabled(store.editor?.isExporting == true)`.

**Update (test migration)**
- `Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift`
- `Tests/DiagramKitTests/Interactive/DiagramEditorFlowchartTests.swift`
- `Tests/DiagramKitTests/Interactive/DiagramEditorUndoTests.swift`
- `Tests/DiagramKitTests/Interactive/DiagramEditorSourceSyncTests.swift`
- `Tests/DiagramKitTests/Interactive/DiagramEditorTests.swift`

**Create**
- `Tests/DiagramKitTests/Interactive/DiagramEditorAsyncExportTests.swift` — new tests for serialization order, `isExporting` transitions, cancellation isolation, off-MainActor worker hop, atomicity under exporter throw.

---

## Task 1: Add Apple-conditional CG dependency to Interactive

**Files:**
- Modify: `Package.swift` (around line 115-118 — `DiagramKitInteractive` target)

- [ ] **Step 1: Capture pre-change state**

Run: `swift build --target DiagramKitInteractive 2>&1 | tail -3`
Expected: PASS (`Build complete!`). Confirms the baseline compiles before any change.

- [ ] **Step 2: Add the conditional dependency**

Modify `Package.swift`. Locate the existing `DiagramKitInteractive` target (currently lines 114-118) and replace it with:

```swift
.target(
    name: "DiagramKitInteractive",
    dependencies: [
        "DiagramKitCommon",
        "DiagramKitModel",
        "DiagramKitImport",
        "DiagramKitExport",
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

- [ ] **Step 3: Re-resolve and rebuild**

Run: `swift package resolve && swift build --target DiagramKitInteractive 2>&1 | tail -5`
Expected: PASS. `swift package resolve` is required after dependency edits per `CLAUDE.md`.

- [ ] **Step 4: Sanity-check umbrella still builds**

Run: `swift build --target DiagramKit 2>&1 | tail -3`
Expected: PASS. Catches any accidental Linux-condition regression in the umbrella's existing Interactive edge.

- [ ] **Step 5: Commit**

```bash
git add Package.swift
git commit -m "$(cat <<'EOF'
build(spm): add Apple-conditional CG dep to DiagramKitInteractive

Lets DiagramEditor dispatch through DiagramWorkerThread.run for
async export. Edge is platform-gated so DiagramKitInteractive
remains buildable on Linux via a private fresh-Thread fallback
(landing in Task 2).
EOF
)"
```

---

## Task 2: Add private `_runOnWorker` helper inside Interactive

**Files:**
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+SourceSync.swift`

- [ ] **Step 1: Replace the file with the helper + the existing sync `_export` and `syncSource`**

Replace the entire contents of `Sources/DiagramKitInteractive/DiagramEditor+SourceSync.swift` with:

```swift
// Phase 9: Interactive Model — Slice 9C
// Source sync via export protocol.

import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import Foundation

#if canImport(CoreGraphics)
import DiagramKitRenderingCG
#endif

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

    // MARK: - Worker hop

    /// Dispatch `work` to a fresh 8 MB worker thread per CLAUDE.md's
    /// no-thread-pool rule. On Apple platforms this forwards to
    /// `DiagramWorkerThread.run` from `DiagramKitRenderingCG`. On Linux,
    /// spins a fresh `Thread` with the stack size from
    /// `DiagramWorkerConfig`.
    static func _runOnWorker<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        #if canImport(CoreGraphics)
        return try await DiagramWorkerThread.run(work)
        #else
        return try await withCheckedThrowingContinuation { continuation in
            let thread = Thread {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            thread.name = "DiagramKit editor worker"
            thread.stackSize = DiagramWorkerConfig.stackSize
            thread.start()
        }
        #endif
    }
}
```

This keeps `_export` and `syncSource` synchronous for now — Tasks 3-5 promote them to async. Landing the helper first lets each subsequent task be a self-contained API migration.

- [ ] **Step 2: Build**

Run: `swift build --target DiagramKitInteractive 2>&1 | tail -3`
Expected: PASS.

- [ ] **Step 3: Run existing editor tests to verify no regression**

Run: `swift test --filter Interactive 2>&1 | tail -5`
Expected: PASS (same count as before).

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitInteractive/DiagramEditor+SourceSync.swift
git commit -m "$(cat <<'EOF'
feat(interactive): add _runOnWorker helper for fresh-thread dispatch

Forwards to DiagramKitRenderingCG's DiagramWorkerThread on Apple
platforms; falls back to a fresh Thread sized by
DiagramWorkerConfig.stackSize on Linux. Sets up the worker hop
that Tasks 3-5 will route DiagramExportLoader.export through.
EOF
)"
```

---

## Task 3: Promote `perform` to `async throws`; introduce `_exportAsync`

This task is the API break for `DiagramMutation`. Migrate the method, sweep every existing caller (tests and playground), and delete the sync `_export`. One atomic commit.

**Files:**
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift` (replace `perform`)
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+SourceSync.swift` (replace `_export` with `_exportAsync`)
- Modify: `Examples/DiagramPlayground/Models/LiveEditorStore.swift` (line 852 — `performMutation`)
- Modify: `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift` (lines 142, 145, 253, 463 — `try? store.performMutation`)
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift` (28 callsites)
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorUndoTests.swift` (10 callsites; one is `syncSource` — leave sync for Task 5)

- [ ] **Step 1: Replace `_export` with `_exportAsync` in source-sync extension**

In `Sources/DiagramKitInteractive/DiagramEditor+SourceSync.swift`, replace the existing `_export` function (currently `func _export(_ document:) throws -> DiagramExportResult`) with:

```swift
/// Internal helper: export without mutating state, off MainActor.
///
/// Used by `perform`/`performFlowchart` to validate the round-trip
/// before state swap. Hops to a fresh worker thread per CLAUDE.md's
/// no-thread-pool rule.
func _exportAsync(_ document: DiagramDocument) async throws -> DiagramExportResult {
    let format = preferredExportFormat
    let registry = exportRegistry
    return try await Self._runOnWorker {
        try DiagramExportLoader.export(
            document, to: format, registry: registry
        )
    }
}
```

Delete the old `_export(_:)` function entirely. `syncSource()` stays sync for now (Task 5 promotes it).

- [ ] **Step 2: Promote `perform` to `async throws`**

In `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift`, replace the `perform(_:)` function (currently lines 24-55) with:

```swift
/// Perform a core mutation on the document.
///
/// Derives the new document from the mutation, exports it through
/// `preferredExportFormat` on a fresh worker thread, then commits
/// state and registers an undo action. If derivation or export
/// throws, no state changes.
///
/// - Parameter mutation: The mutation to apply.
/// - Throws: `DiagramEditorError` if the mutation cannot be applied
///   or source sync fails.
public func perform(_ mutation: DiagramMutation) async throws {
    let newDocument = try _apply(mutation, to: document)

    let exportResult: DiagramExportResult
    do {
        exportResult = try await _exportAsync(newDocument)
    } catch {
        throw DiagramEditorError.sourceSyncFailed(underlying: error.localizedDescription)
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

The commit body is intentionally inline rather than extracted yet — Task 6 will refactor it into `_performInner` when adding the chained-task pattern.

- [ ] **Step 3: Migrate `LiveEditorStore.performMutation` to async**

In `Examples/DiagramPlayground/Models/LiveEditorStore.swift`, replace the `performMutation(_:)` function (currently lines 852-865) with:

```swift
/// Apply a core mutation through the persistent editor, then push the
/// exported source back into `state.source` (origin: `.mutation` so the
/// post-render seed step skips re-creating the editor and preserves
/// the undo stack).
///
/// No-ops silently when `editor` is nil — the pane gates buttons on
/// `store.editor != nil`, so this only protects against races.
public func performMutation(_ mutation: DiagramMutation) async throws {
    guard let editor else { return }
    do {
        try await editor.perform(mutation)
        lastMutationError = nil
        if let source = editor.source, source != state.source {
            setSource(source, origin: .mutation)
        }
        _bumpUndoTickle()
    } catch {
        lastMutationError = error.localizedDescription
        throw error
    }
}
```

- [ ] **Step 4: Migrate the four `try? store.performMutation` button callsites**

In `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`, wrap each of the four call sites in a `Task`:

Replace at line 142:
```swift
Button("Set") {
    try? store.performMutation(.setTitle(draft.isEmpty ? nil : draft))
}
```
with:
```swift
Button("Set") {
    Task { try? await store.performMutation(.setTitle(draft.isEmpty ? nil : draft)) }
}
```

Replace at line 145:
```swift
Button("Clear") {
    try? store.performMutation(.setTitle(nil))
}
```
with:
```swift
Button("Clear") {
    Task { try? await store.performMutation(.setTitle(nil)) }
}
```

Replace at line 253:
```swift
try? store.performMutation(.setLabel(of: selection, to: draft))
```
with:
```swift
Task { try? await store.performMutation(.setLabel(of: selection, to: draft)) }
```

Replace at line 463:
```swift
try? store.performMutation(.deleteElement(selection))
```
with:
```swift
Task { try? await store.performMutation(.deleteElement(selection)) }
```

The `.disabled(store.editor?.isExporting == true)` modifier is added in Task 10 once `isExporting` exists.

- [ ] **Step 5: Sweep existing tests for `editor.perform(...)` callsites**

Run: `grep -rn "editor\.perform(\." Tests/DiagramKitTests/Interactive/ | grep -v "performFlowchart"`
Expected: 28 hits across `DiagramEditorMutationTests.swift` and `DiagramEditorUndoTests.swift`.

For each hit, do **two** transforms:

(a) Replace `try editor.perform(...)` with `try await editor.perform(...)`.

(b) Make the enclosing `@Test` function `async` if it isn't already. swift-testing supports `@Test func foo() async throws`. If the function is currently `func foo() throws`, add `async` before `throws`.

Apply this exact sed-like rewrite per file (manual, with care — `editor.perform` may appear inside `#expect(throws:) { ... }` closures):

For each callsite of the form:
```swift
try editor.perform(.deleteElement(sel))
```
becomes:
```swift
try await editor.perform(.deleteElement(sel))
```

For each callsite inside an `#expect(throws:) { ... }` closure:
```swift
#expect(throws: DiagramEditorError.self) {
    try editor.perform(.deleteElement(sel))
}
```
the `#expect(throws:)` closure in swift-testing supports throwing **non-async** closures only. Convert to:
```swift
await #expect(throws: DiagramEditorError.self) {
    try await editor.perform(.deleteElement(sel))
}
```
Note: swift-testing 0.10+ exposes `#expect(throws:performing:)` with an async overload. If the test target's swift-testing version doesn't have the async overload, fall back to:
```swift
do {
    try await editor.perform(.deleteElement(sel))
    Issue.record("expected throw")
} catch let error as DiagramEditorError {
    // assertions
}
```

For each enclosing function, prepend `async` to the signature:
```swift
@Test("description")
func name() throws { ... }
```
becomes:
```swift
@Test("description")
func name() async throws { ... }
```

The full sweep affects exactly these tests in `DiagramEditorMutationTests.swift`:
- `deleteElementNode`, `deleteElementEdge`, `deleteElementUniqueEdge`, `deleteElementDuplicateEdgeFirst`, `deleteElementDuplicateEdgeSecond`, `deleteElementMissingNodeThrows`, `deleteElementMissingEdgeThrows`, `deleteElementUnknownKindThrows`, `setLabelNode`, `setLabelEdge`, `setLabelDuplicateEdge`, `setLabelMissingNodeThrows`, `setLabelMissingEdgeThrows`, `setTitle`, `setTitleNilClears`, plus the state-diagram counterparts.

And these in `DiagramEditorUndoTests.swift`:
- All `@Test func` cases that call `editor.perform`. Leave the lone `editor.syncSource()` callsite on line 65 as-is (sync; Task 5 migrates it).

- [ ] **Step 6: Build**

Run: `swift build --target DiagramKitInteractive --target DiagramPlayground 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 7: Run editor tests**

Run: `swift test --filter "DiagramEditorMutationTests|DiagramEditorUndoTests" 2>&1 | tail -10`
Expected: PASS. All previously-passing tests continue to pass under the async API.

- [ ] **Step 8: Commit**

```bash
git add Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift \
        Sources/DiagramKitInteractive/DiagramEditor+SourceSync.swift \
        Examples/DiagramPlayground/Models/LiveEditorStore.swift \
        Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift \
        Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift \
        Tests/DiagramKitTests/Interactive/DiagramEditorUndoTests.swift
git commit -m "$(cat <<'EOF'
feat(interactive): perform(_:) becomes async throws, hops worker

DiagramEditor.perform now dispatches DiagramExportLoader.export
through DiagramEditor._runOnWorker (8 MB fresh-thread per
CLAUDE.md). Atomic commit contract preserved: a worker-side throw
leaves state untouched.

Internal _export is replaced by _exportAsync. LiveEditorStore.
performMutation and the four DiagramEditorPane button callsites
become async; tests in DiagramEditorMutationTests and
DiagramEditorUndoTests gain try await.
EOF
)"
```

---

## Task 4: Promote `performFlowchart` to `async throws`

Same pattern as Task 3, scoped to the flowchart entry point.

**Files:**
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift` (lines 83-116)
- Modify: `Examples/DiagramPlayground/Models/LiveEditorStore.swift` (lines 870-883 — `performFlowchartMutation`)
- Modify: `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift` (lines 329, 441)
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorFlowchartTests.swift`

- [ ] **Step 1: Promote `performFlowchart` to `async throws`**

In `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift`, replace the `performFlowchart(_:)` function (currently lines 83-116) with:

```swift
/// Perform a flowchart-specific mutation.
///
/// - Parameter mutation: The flowchart mutation to apply.
/// - Throws: `DiagramEditorError` if the document is not a flowchart,
///   the mutation cannot be applied, or source sync fails.
public func performFlowchart(_ mutation: FlowchartMutation) async throws {
    guard case .flowchart = document.payload else {
        throw DiagramEditorError.notAFlowchart
    }

    let newDocument = try _applyFlowchart(mutation, to: document)

    let exportResult: DiagramExportResult
    do {
        exportResult = try await _exportAsync(newDocument)
    } catch {
        throw DiagramEditorError.sourceSyncFailed(underlying: error.localizedDescription)
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

- [ ] **Step 2: Migrate `LiveEditorStore.performFlowchartMutation` to async**

In `Examples/DiagramPlayground/Models/LiveEditorStore.swift`, replace `performFlowchartMutation` (currently lines 870-883) with:

```swift
/// Apply a flowchart-specific mutation through the persistent editor.
///
/// No-ops silently when `editor` is nil.
public func performFlowchartMutation(_ mutation: FlowchartMutation) async throws {
    guard let editor else { return }
    do {
        try await editor.performFlowchart(mutation)
        lastMutationError = nil
        if let source = editor.source, source != state.source {
            setSource(source, origin: .mutation)
        }
        _bumpUndoTickle()
    } catch {
        lastMutationError = error.localizedDescription
        throw error
    }
}
```

- [ ] **Step 3: Migrate the two flowchart button callsites**

In `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`, find the `try store.performFlowchartMutation(...)` callsites (lines 329 and 441). These are currently inside `do { ... } catch { ... }` blocks. Convert each enclosing handler:

Around line 329, replace:
```swift
do {
    try store.performFlowchartMutation(.insertNode(id: id, label: labelDraft, type: shape.rawValue))
    // ... reset draft, etc.
} catch {
    // surface error
}
```
with:
```swift
Task {
    do {
        try await store.performFlowchartMutation(.insertNode(id: id, label: labelDraft, type: shape.rawValue))
        // ... reset draft, etc.
    } catch {
        // surface error
    }
}
```

Same shape for line 441 (`insertEdge`).

If the surrounding code captures `@State` properties that the handler resets, the `Task` body runs on `@MainActor` because `DiagramEditorPane` is a `View` whose body is `@MainActor`-isolated. Captures of `@State` bindings are safe.

- [ ] **Step 4: Sweep `DiagramEditorFlowchartTests.swift` callsites**

Run: `grep -n "editor\.performFlowchart" Tests/DiagramKitTests/Interactive/DiagramEditorFlowchartTests.swift`
Expected: 9 hits at lines 65, 84, 103, 116, 130, 153, 174, 189, 203.

For each callsite, replace `try editor.performFlowchart(...)` with `try await editor.performFlowchart(...)` and prepend `async` to the enclosing `@Test func` signature. Apply the same `#expect(throws:)` strategy from Task 3 Step 5 if any callsite is inside a throwing-assertion closure.

- [ ] **Step 5: Build and test**

Run: `swift build --target DiagramKitInteractive --target DiagramPlayground 2>&1 | tail -3`
Expected: PASS.

Run: `swift test --filter DiagramEditorFlowchartTests 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift \
        Examples/DiagramPlayground/Models/LiveEditorStore.swift \
        Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift \
        Tests/DiagramKitTests/Interactive/DiagramEditorFlowchartTests.swift
git commit -m "$(cat <<'EOF'
feat(interactive): performFlowchart(_:) becomes async throws

Same worker-hop migration as perform(_:): export runs through
DiagramEditor._runOnWorker. LiveEditorStore.performFlowchartMutation,
the two DiagramEditorPane flowchart-insert buttons, and the
DiagramEditorFlowchartTests suite all migrate to async.
EOF
)"
```

---

## Task 5: Promote `syncSource` to `async throws`; delete sync `_export`

**Files:**
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+SourceSync.swift`
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorSourceSyncTests.swift`
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorUndoTests.swift` (line 65)

- [ ] **Step 1: Promote `syncSource` to async**

In `Sources/DiagramKitInteractive/DiagramEditor+SourceSync.swift`, replace the entire `syncSource()` function with:

```swift
/// Re-export the current document via `preferredExportFormat`.
///
/// Hops to a fresh 8 MB worker thread; sets `source` to the exported
/// source text and `lastExportDiagnostics` to any non-fatal
/// diagnostics on success.
///
/// - Throws: `DiagramExportError` if no exporter is registered for
///   `preferredExportFormat`, or if the exporter throws a fatal error.
public func syncSource() async throws {
    let result = try await _exportAsync(document)
    _commitSource(result.source)
    _commitDiagnostics(result.diagnostics)
}
```

- [ ] **Step 2: Sweep test callsites**

Run: `grep -rn "editor\.syncSource" Tests/DiagramKitTests/`
Expected: hits in `DiagramEditorSourceSyncTests.swift` and `DiagramEditorUndoTests.swift:65`.

For each hit:
- Replace `try editor.syncSource()` with `try await editor.syncSource()`.
- Prepend `async` to the enclosing `@Test func` signature if needed.

- [ ] **Step 3: Verify no sync `_export` callers remain**

Run: `grep -rn "_export(" Sources/DiagramKitInteractive/ Tests/`
Expected: no hits (only `_exportAsync` and `_export(...)` inside the function declaration line — but the function itself was removed in Task 3 Step 1, so nothing should match the open paren form except `_exportAsync`).

If any `_export(` hits remain, treat them as a mistake — fix and re-run.

- [ ] **Step 4: Build and test**

Run: `swift build --target DiagramKitInteractive 2>&1 | tail -3`
Expected: PASS.

Run: `swift test --filter "DiagramEditorSourceSyncTests|DiagramEditorUndoTests" 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitInteractive/DiagramEditor+SourceSync.swift \
        Tests/DiagramKitTests/Interactive/DiagramEditorSourceSyncTests.swift \
        Tests/DiagramKitTests/Interactive/DiagramEditorUndoTests.swift
git commit -m "$(cat <<'EOF'
feat(interactive): syncSource becomes async throws

Last sync mutation entry point promoted to async. The internal
sync _export helper has no remaining callers and is deleted.
DiagramEditorSourceSyncTests + the lone syncSource call in
DiagramEditorUndoTests gain try await.
EOF
)"
```

---

## Task 6: Add `isExporting` observable + chained-Task serialization

This is the TDD step: write a failing serialization test, then implement the chained-Task pattern + refcount. The plan adds the pattern to both `perform` and `performFlowchart`; the commit-body extraction (`_performInner` / `_performFlowchartInner`) is part of this task because the chained Task wraps the commit body.

**Files:**
- Modify: `Sources/DiagramKitInteractive/DiagramEditor.swift` (add `isExporting`, `pendingMutation`, `mutationDepth`)
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift` (extract `_performInner`, add chained Task to `perform`)
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift` (extract `_performFlowchartInner`, add chained Task to `performFlowchart`)
- Create: `Tests/DiagramKitTests/Interactive/DiagramEditorAsyncExportTests.swift`

- [ ] **Step 1: Write the failing serialization test**

Create `Tests/DiagramKitTests/Interactive/DiagramEditorAsyncExportTests.swift`:

```swift
// Async export behavior: serialization, isExporting transitions,
// cancellation isolation, off-MainActor worker hop, atomicity
// under exporter throw.

import Testing
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
@testable import DiagramKitInteractive

// MARK: - Test exporter that emits the current node count

private struct CountingExporter: DiagramExporter {
    let name: String = "Counting"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart]

    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        let n: Int
        switch document.payload {
        case .flowchart(let m): n = m.nodesInOrder.count
        default: n = -1
        }
        return DiagramExportResult(source: "n=\(n)")
    }
}

private func flowDoc(_ nodes: [String]) -> DiagramDocument {
    let mNodes = nodes.map { id in
        (id: id, node: original_src_types.MermaidNode(
            id: id, label: id, shape: .rectangle
        ))
    }
    let model = original_src_types.MermaidGraph(
        direction: .TD, nodesInOrder: mNodes, edges: []
    )
    return DiagramDocument(payload: .flowchart(model))
}

private func makeEditor(_ nodes: [String] = ["A"]) -> DiagramEditor {
    DiagramEditor(
        document: flowDoc(nodes),
        preferredExportFormat: .mermaid,
        exportRegistry: ExporterRegistry.empty.registering(CountingExporter())
    )
}

@Suite @MainActor
struct DiagramEditorAsyncExportTests {

    @Test("Two perform calls fired without intermediate awaits commit in order")
    func serializesOverlappingPerforms() async throws {
        let editor = makeEditor(["A"])

        let t1 = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "B", label: "B"))
        }
        let t2 = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "C", label: "C"))
        }
        try await t1.value
        try await t2.value

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false), "expected flowchart")
            return
        }
        // Both inserts landed
        #expect(model.nodesInOrder.map(\.id) == ["A", "B", "C"])
        // Two undo entries — each mutation got its own
        #expect(editor.undoManager.canUndo == true)
        editor.undoManager.undo()
        editor.undoManager.undo()
        if case .flowchart(let m0) = editor.document.payload {
            #expect(m0.nodesInOrder.map(\.id) == ["A"])
        } else {
            #expect(Bool(false), "expected flowchart after two undos")
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails the right way**

Run: `swift test --filter DiagramEditorAsyncExportTests 2>&1 | tail -15`
Expected: At this point the test may PASS by accident (single-threaded MainActor + fast in-process worker often serializes naturally). If it passes, the test still has value as a regression net — proceed. If it fails, capture the failure (likely a node-order or undo-depth mismatch) and proceed.

This is the one place TDD is approximate — the race the test is guarding against is non-deterministic without the chained-Task pattern. The pattern is still required by the spec.

- [ ] **Step 3: Add `pendingMutation` and `mutationDepth` to `DiagramEditor`**

In `Sources/DiagramKitInteractive/DiagramEditor.swift`, after the `lastExportDiagnostics` declaration (around line 81), add:

```swift
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

    /// Refcount of `perform`/`performFlowchart` callers currently on
    /// the chain. `isExporting` flips on transitions 0→1 and N→0.
    @ObservationIgnored
    private var _mutationDepth: Int = 0
```

`@ObservationIgnored` keeps the private state out of `@Observable` change tracking — SwiftUI only re-evaluates when `isExporting` itself changes.

- [ ] **Step 4: Add internal helpers for the chained-Task pattern**

In `Sources/DiagramKitInteractive/DiagramEditor.swift`, after `_commitDiagnostics`, add:

```swift
    // MARK: - Async mutation chain helpers

    /// Increment the in-flight refcount. Called by `perform` and
    /// `performFlowchart` on entry. Flips `isExporting` to `true` on
    /// the 0→1 transition.
    func _enterMutationChain() {
        _mutationDepth += 1
        if _mutationDepth == 1 { isExporting = true }
    }

    /// Decrement the in-flight refcount. Called from `defer` on exit.
    /// Flips `isExporting` to `false` on the N→0 transition.
    func _exitMutationChain() {
        _mutationDepth -= 1
        if _mutationDepth == 0 { isExporting = false }
    }

    /// Await any currently-pending mutation Task before starting a
    /// new one. Errors from the previous task are absorbed (`try?`)
    /// so a failed mutation does not stop later ones from running.
    func _awaitPendingMutation() async {
        if let pending = _pendingMutation {
            _ = try? await pending.value
        }
    }

    /// Record `task` as the new pending mutation and clear it on
    /// completion if no later task has overwritten it.
    func _setPendingMutation(_ task: Task<Void, Error>) {
        _pendingMutation = task
    }

    /// Clear `_pendingMutation` only if it still references `task`.
    /// Called from each caller's `defer`.
    func _clearPendingMutationIfCurrent(_ task: Task<Void, Error>) {
        if _pendingMutation === task {
            _pendingMutation = nil
        }
    }
```

- [ ] **Step 5: Rewrite `perform` to use the chained-Task pattern**

In `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift`, replace `perform(_:)` (the version landed in Task 3) with:

```swift
/// Perform a core mutation on the document.
///
/// Derives the new document, exports it on a fresh worker thread,
/// and commits state + undo atomically. Concurrent calls serialize:
/// each caller awaits the previous mutation's task before starting
/// its own, so commits land in registration order and each gets its
/// own undo entry.
///
/// - Parameter mutation: The mutation to apply.
/// - Throws: `DiagramEditorError` if the mutation cannot be applied
///   or source sync fails.
public func perform(_ mutation: DiagramMutation) async throws {
    _enterMutationChain()
    defer { _exitMutationChain() }

    await _awaitPendingMutation()

    let task = Task { @MainActor [weak self] in
        guard let self else { return }
        try await self._performInner(mutation)
    }
    _setPendingMutation(task)
    defer { _clearPendingMutationIfCurrent(task) }

    try await task.value
}

/// Inner commit body. Always runs on `MainActor`. Atomic: a throw
/// from the worker leaves state untouched.
func _performInner(_ mutation: DiagramMutation) async throws {
    let newDocument = try _apply(mutation, to: document)

    let exportResult: DiagramExportResult
    do {
        exportResult = try await _exportAsync(newDocument)
    } catch {
        throw DiagramEditorError.sourceSyncFailed(underlying: error.localizedDescription)
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

- [ ] **Step 6: Rewrite `performFlowchart` the same way**

In `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift`, replace `performFlowchart(_:)` with:

```swift
/// Perform a flowchart-specific mutation. Same serialization +
/// atomicity contract as `perform`.
///
/// - Parameter mutation: The flowchart mutation to apply.
/// - Throws: `DiagramEditorError` if the document is not a flowchart,
///   the mutation cannot be applied, or source sync fails.
public func performFlowchart(_ mutation: FlowchartMutation) async throws {
    _enterMutationChain()
    defer { _exitMutationChain() }

    await _awaitPendingMutation()

    let task = Task { @MainActor [weak self] in
        guard let self else { return }
        try await self._performFlowchartInner(mutation)
    }
    _setPendingMutation(task)
    defer { _clearPendingMutationIfCurrent(task) }

    try await task.value
}

func _performFlowchartInner(_ mutation: FlowchartMutation) async throws {
    guard case .flowchart = document.payload else {
        throw DiagramEditorError.notAFlowchart
    }

    let newDocument = try _applyFlowchart(mutation, to: document)

    let exportResult: DiagramExportResult
    do {
        exportResult = try await _exportAsync(newDocument)
    } catch {
        throw DiagramEditorError.sourceSyncFailed(underlying: error.localizedDescription)
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

- [ ] **Step 7: Add the isExporting transition test**

In `Tests/DiagramKitTests/Interactive/DiagramEditorAsyncExportTests.swift`, after the existing `@Test` block but inside the `DiagramEditorAsyncExportTests` `@Suite`, add a gated exporter that blocks inside `export(...)` until the test releases it, so the test can observe `isExporting == true` between the request and the release:

```swift
    @Test("isExporting is false at rest, true during a mutation, false after")
    func isExportingTransitions() async throws {
        actor Gate {
            private var continuation: CheckedContinuation<Void, Never>?
            func wait() async {
                await withCheckedContinuation { self.continuation = $0 }
            }
            func release() { continuation?.resume(); continuation = nil }
        }
        let gate = Gate()

        struct GatedExporter: DiagramExporter {
            let name: String = "Gated"
            let formatID: DiagramFormatID = .mermaid
            let supportedDiagramTypes: Set<DiagramType> = [.flowchart]
            let gate: Gate
            func export(_ document: DiagramDocument) throws -> DiagramExportResult {
                let sema = DispatchSemaphore(value: 0)
                Task { await gate.wait(); sema.signal() }
                sema.wait()
                return DiagramExportResult(source: "gated")
            }
        }

        let editor = DiagramEditor(
            document: flowDoc(["A"]),
            preferredExportFormat: .mermaid,
            exportRegistry: ExporterRegistry.empty.registering(GatedExporter(gate: gate))
        )
        #expect(editor.isExporting == false)

        let task = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "B", label: "B"))
        }
        // Let `perform` reach the worker — 50 ms tolerance for the
        // MainActor → fresh-Thread hop.
        try await Task.sleep(for: .milliseconds(50))
        #expect(editor.isExporting == true)
        await gate.release()
        try await task.value
        #expect(editor.isExporting == false)
    }
```

- [ ] **Step 8: Build and test**

Run: `swift build --target DiagramKitInteractive --target DiagramPlayground 2>&1 | tail -3`
Expected: PASS.

Run: `swift test --filter "DiagramEditorAsyncExportTests|DiagramEditorMutationTests|DiagramEditorFlowchartTests|DiagramEditorUndoTests" 2>&1 | tail -8`
Expected: PASS. Both new tests + all existing tests green.

- [ ] **Step 9: Commit**

```bash
git add Sources/DiagramKitInteractive/DiagramEditor.swift \
        Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift \
        Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift \
        Tests/DiagramKitTests/Interactive/DiagramEditorAsyncExportTests.swift
git commit -m "$(cat <<'EOF'
feat(interactive): chained-Task serialization + isExporting

DiagramEditor.perform and .performFlowchart now run their commit
body inside a Task that the next caller awaits. A refcount
(_mutationDepth) drives the isExporting Observable property
without mid-chain flicker. Atomic-commit contract preserved.

New DiagramEditorAsyncExportTests covers two-call ordering and
isExporting on/off transitions.
EOF
)"
```

---

## Task 7: Add atomicity-under-throw test

**Files:**
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorAsyncExportTests.swift`

- [ ] **Step 1: Add the test**

Append inside the `DiagramEditorAsyncExportTests` `@Suite`:

```swift
    @Test("A throwing exporter leaves document, source, and undo stack untouched")
    func atomicityUnderExporterThrow() async throws {
        struct FailingExporter: DiagramExporter {
            let name: String = "Failing"
            let formatID: DiagramFormatID = .mermaid
            let supportedDiagramTypes: Set<DiagramType> = [.flowchart]
            func export(_ document: DiagramDocument) throws -> DiagramExportResult {
                throw DiagramExportError.exporterFailed(name: name, underlying: "boom")
            }
        }
        let editor = DiagramEditor(
            document: flowDoc(["A"]),
            preferredExportFormat: .mermaid,
            exportRegistry: ExporterRegistry.empty.registering(FailingExporter())
        )

        let preDocument = editor.document
        let preSource = editor.source
        let preCanUndo = editor.undoManager.canUndo

        do {
            try await editor.performFlowchart(.insertNode(id: "B", label: "B"))
            #expect(Bool(false), "expected throw")
        } catch {
            // Pass — we expect a sourceSyncFailed.
        }

        #expect(editor.document == preDocument)
        #expect(editor.source == preSource)
        #expect(editor.undoManager.canUndo == preCanUndo)
        #expect(editor.isExporting == false)
    }
```

Note: `DiagramDocument` needs to be `Equatable` for `editor.document == preDocument`. If it is not, replace the equality check with structural assertions on `editor.document.payload` (e.g. `case .flowchart(let m) = ...; #expect(m.nodesInOrder.count == 1)`).

- [ ] **Step 2: Run**

Run: `swift test --filter "DiagramEditorAsyncExportTests/atomicityUnderExporterThrow" 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add Tests/DiagramKitTests/Interactive/DiagramEditorAsyncExportTests.swift
git commit -m "test(interactive): atomicity preserved when exporter throws"
```

---

## Task 8: Add cancellation isolation test

**Files:**
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorAsyncExportTests.swift`

- [ ] **Step 1: Add the test**

Append inside the `DiagramEditorAsyncExportTests` `@Suite`:

```swift
    @Test("Cancelling the outer Task does not abort the in-flight commit")
    func cancellationIsolation() async throws {
        let editor = makeEditor(["A"])

        let task = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "B", label: "B"))
        }
        // Give the inner Task a moment to start the worker hop, then cancel
        // the outer Task. The inner Task should still complete.
        try await Task.sleep(for: .milliseconds(10))
        task.cancel()
        // Awaiting a cancelled Task throws CancellationError if the task
        // observed cancellation; if it completed before observing the
        // cancellation, .value returns normally. Either path is acceptable
        // for this test — what matters is the editor state after.
        _ = try? await task.value

        // Drain any continuation work.
        try await Task.sleep(for: .milliseconds(50))

        // The mutation committed despite cancellation: B is now in the document.
        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false), "expected flowchart")
            return
        }
        #expect(model.nodesInOrder.map(\.id).contains("B"))
        #expect(editor.isExporting == false)
    }
```

- [ ] **Step 2: Run**

Run: `swift test --filter "DiagramEditorAsyncExportTests/cancellationIsolation" 2>&1 | tail -5`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add Tests/DiagramKitTests/Interactive/DiagramEditorAsyncExportTests.swift
git commit -m "test(interactive): cancelling the awaiter does not abort the commit"
```

---

## Task 9: Add off-MainActor assertion test

**Files:**
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorAsyncExportTests.swift`

- [ ] **Step 1: Add the test**

Append inside the `DiagramEditorAsyncExportTests` `@Suite`:

```swift
    @Test("Export runs off MainActor")
    func exportRunsOffMainActor() async throws {
        actor ThreadObserver {
            private(set) var sawOffMainActor: Bool = false
            func record(isMain: Bool) { if !isMain { sawOffMainActor = true } }
        }
        let observer = ThreadObserver()

        struct ObservingExporter: DiagramExporter {
            let name: String = "Observing"
            let formatID: DiagramFormatID = .mermaid
            let supportedDiagramTypes: Set<DiagramType> = [.flowchart]
            let observer: ThreadObserver
            func export(_ document: DiagramDocument) throws -> DiagramExportResult {
                let isMain = Thread.isMainThread
                // Record synchronously by hopping back through a semaphore.
                let sema = DispatchSemaphore(value: 0)
                Task { await observer.record(isMain: isMain); sema.signal() }
                sema.wait()
                return DiagramExportResult(source: "observed")
            }
        }

        let editor = DiagramEditor(
            document: flowDoc(["A"]),
            preferredExportFormat: .mermaid,
            exportRegistry: ExporterRegistry.empty.registering(ObservingExporter(observer: observer))
        )

        try await editor.performFlowchart(.insertNode(id: "B", label: "B"))

        let sawOff = await observer.sawOffMainActor
        #expect(sawOff == true, "exporter must run off MainActor (DiagramWorkerThread)")
    }
```

- [ ] **Step 2: Run**

Run: `swift test --filter "DiagramEditorAsyncExportTests/exportRunsOffMainActor" 2>&1 | tail -5`
Expected: PASS. The exporter callback observed `Thread.isMainThread == false`, proving the worker hop fires.

- [ ] **Step 3: Commit**

```bash
git add Tests/DiagramKitTests/Interactive/DiagramEditorAsyncExportTests.swift
git commit -m "test(interactive): exporter callback runs off MainActor"
```

---

## Task 10: Wire `isExporting` into `DiagramEditorPane`

**Files:**
- Modify: `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`

- [ ] **Step 1: Add `.disabled(store.editor?.isExporting == true)` to mutation buttons**

In `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`, locate each mutation button (the four `Button` views that wrap the `Task { try? await store.performMutation(...) }` calls migrated in Task 3, plus the two flowchart-insert sections from Task 4) and add the modifier:

For the title-set/clear buttons (around lines 141-147 after Task 3's wrapping):
```swift
Button("Set") {
    Task { try? await store.performMutation(.setTitle(draft.isEmpty ? nil : draft)) }
}
.disabled(store.editor?.isExporting == true)

Button("Clear") {
    Task { try? await store.performMutation(.setTitle(nil)) }
}
.disabled(store.editor?.isExporting == true || editor.document.title == nil)
```

For the label-edit button (around line 253):
```swift
Button("Apply") {
    Task { try? await store.performMutation(.setLabel(of: selection, to: draft)) }
}
.disabled(store.editor?.isExporting == true)
```

For the delete button (around line 463):
```swift
Button(role: .destructive) {
    Task { try? await store.performMutation(.deleteElement(selection)) }
} label: { /* ... */ }
.disabled(store.editor?.isExporting == true)
```

For the two insert sections (around lines 329 and 441) — these are inside `InsertNodeSection` / `InsertEdgeSection` subviews. Add the same `.disabled(store.editor?.isExporting == true)` to the primary insert button in each subview.

- [ ] **Step 2: Build the playground**

Run: `swift build --target DiagramPlayground 2>&1 | tail -3`
Expected: PASS.

- [ ] **Step 3: Manual smoke (optional but recommended)**

Run: `swift run DiagramPlayground`

Open a non-trivial flowchart from the corpus. Mutate (add a node) and visually confirm:
- The button briefly disables during the worker hop.
- The mutation lands; undo restores it.

This is a manual check; capture the observation in the commit message.

- [ ] **Step 4: Commit**

```bash
git add Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift
git commit -m "$(cat <<'EOF'
feat(playground): disable mutation buttons during in-flight export

Reads store.editor?.isExporting to grey out the title/label/delete
and insert-node/insert-edge buttons while the worker hop is
outstanding. Prevents rapid-fire taps from piling up Tasks behind
a single in-flight commit.
EOF
)"
```

---

## Task 11: Run discipline gates and verify

**Files:**
- Run: discipline scripts (no file edits expected).

- [ ] **Step 1: Sendable annotations**

Run: `Scripts/check-sendable-annotations.sh 2>&1 | tail -5`
Expected: PASS. The new `_pendingMutation: Task<Void, Error>?` field is `@MainActor`-isolated (the editor is `@MainActor`), so no `@unchecked Sendable` is required.

- [ ] **Step 2: Strict concurrency**

Run: `Scripts/strict-concurrency-check.sh 2>&1 | tail -10`
Expected: `✓ first-party clean`. Watch for any new warnings on `Task { @MainActor [weak self] in ... }` patterns — if any appear, fix the capture list (`[weak self]` is required, not optional) before declaring the gate green.

- [ ] **Step 3: File size warnings**

Run: `Scripts/check-file-sizes.sh 2>&1 | tail -10`
Expected: no NEW yellow warnings. Touched files (`DiagramEditor+Mutations.swift`, `DiagramEditor+Flowchart.swift`, `DiagramEditor+SourceSync.swift`, `LiveEditorStore.swift`, `DiagramEditorPane.swift`) should all be below 500 lines or on the existing allowlist.

- [ ] **Step 4: Full editor test sweep**

Run: `swift test --filter "DiagramEditor|LiveEditorStore" 2>&1 | tail -10`
Expected: PASS. This covers `DiagramEditorMutationTests`, `DiagramEditorFlowchartTests`, `DiagramEditorUndoTests`, `DiagramEditorSourceSyncTests`, `DiagramEditorTests`, `DiagramEditorAsyncExportTests`, and any `LiveEditorStore*` tests.

- [ ] **Step 5: Bootstrap smoke check (optional — long-running)**

If time permits and Docker/Podman is available:

Run: `Scripts/bootstrap-smoke-check.sh 2>&1 | tail -20`
Expected: PASS. `linux-check.sh` may record an environment-skip if no container runtime — that is not a failure per `CLAUDE.md`.

If no container runtime, record the skip in the commit message rather than running the gate.

- [ ] **Step 6: Update CLAUDE.md test count if needed**

Run: `find Tests/DiagramKitTests -name "*.swift" | wc -l`

If the count differs from the value in `CLAUDE.md` (currently 218 — line near "Current test source count"), update that line. The new `DiagramEditorAsyncExportTests.swift` brings the count to 219.

```bash
git add CLAUDE.md
git commit -m "docs(claude): sync test source count after async-export tests"
```

- [ ] **Step 7: Final verification commit (only if any gate exposed an issue that required a touch-up)**

If steps 1-5 found something that needed a follow-up edit, commit it with a clear `chore(...)` or `fix(...)` prefix and rerun the affected gate. Otherwise skip.

---

## Notes for the executor

- **Order matters.** Tasks 1 and 2 must land before 3-5. Task 6's chained-Task pattern depends on the async API from 3-5. Tasks 7-9 add tests that exercise the pattern landed in Task 6.
- **Commit granularity.** Tasks 1, 2, 5, 7, 8, 9, 10 produce one commit each. Task 3 produces one large API-migration commit. Task 4 produces one (analogous) commit. Task 6 produces one feature commit. Task 11 produces zero or one chore commit.
- **The 8 MB rule.** `_runOnWorker` in `DiagramEditor+SourceSync.swift` uses `DiagramWorkerThread.run` (Apple) or `Thread` with `DiagramWorkerConfig.stackSize` (Linux). Do not introduce `Task.detached`, `DispatchQueue.global`, or any other thread-pool primitive — the spec and CLAUDE.md both forbid them.
- **`@ObservationIgnored` on `_pendingMutation` and `_mutationDepth`.** Without it, every mutation entry/exit triggers a SwiftUI re-render through the `@Observable` tracking system. Only `isExporting` should be observed.
- **Cancellation contract.** Cancelling a caller's outer `Task` only stops *that caller* from waiting. The inner Task — and the worker it kicks off — runs to completion. Tests in Task 8 pin this.
- **Atomic-commit contract.** A throwing exporter must leave `document`, `source`, `lastExportDiagnostics`, `selection`, and the `undoManager` stack untouched. The throw must happen *before* the commit block runs. Task 7 pins this.

---

## Spec coverage check

- ✓ `perform`, `performFlowchart`, `syncSource` become `async throws` — Tasks 3, 4, 5.
- ✓ `isExporting` observable signal — Task 6.
- ✓ Refcount-driven flicker avoidance — Task 6 (`_mutationDepth`).
- ✓ Worker hop via `DiagramWorkerThread.run` (Apple) / fresh Thread (Linux) — Tasks 1, 2, 3.
- ✓ Atomicity preserved under worker throw — Task 7.
- ✓ Serialization across overlapping calls — Task 6, pinned in Task 6 Step 1 test.
- ✓ Cancellation isolation — Task 8.
- ✓ Off-MainActor execution — Task 9.
- ✓ Playground integration — Tasks 3, 4 (callers), 10 (`.disabled`).
- ✓ Discipline gates green — Task 11.
- ✓ Linux fallback — Task 2 (private `_runOnWorker` Linux branch).
- ✓ Sync `_export` deleted — Task 5 Step 3 verifies no remaining callers.

No spec requirements without a task.
