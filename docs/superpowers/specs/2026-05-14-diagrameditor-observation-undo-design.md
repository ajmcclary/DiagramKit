# DiagramEditor Observation-tracked undo state — design

Last remaining open item from REVIEW.md §4 Playground state machine: lift
the manual `_undoTickle` workaround out of `LiveEditorStore` and into
`DiagramEditor` itself so any consumer can write
`.disabled(!editor.canUndo)` and have SwiftUI re-evaluate correctly.

## Problem

`Foundation.UndoManager` is not Observation-tracked. SwiftUI modifiers
that read `editor.undoManager.canUndo` or `editor.undoManager.canRedo`
only re-evaluate when some other observed property on the same model
changes — so undo/redo buttons drift out of sync with the actual stack.

The playground worked around this at
`Examples/DiagramPlayground/Models/LiveEditorStore.swift:139-165` with a
manual `@ObservationIgnored var _undoTickle: Int` counter, three
computed mirrors (`canUndoStructural`, `canRedoStructural`,
`undoStructuralActionName`), and a private `_bumpUndoTickle()` call
threaded through mutation, undo, redo, and editor-swap sites. The
workaround is correct but lives in the wrong layer — every
`DiagramEditor` consumer would have to reinvent it.

## Goal

Move the responsibility to `DiagramEditor` (the library type that owns
the `UndoManager`). The shims live in `DiagramKitInteractive` so all
Apple-platform consumers — including the playground — read directly
from the editor.

## Non-goals

- **No convenience `editor.undo()` / `editor.redo()` methods.**
  Consumers already call `editor.undoManager.undo()`; the
  NotificationCenter path picks that up, so a wrapper method would be
  redundant API surface.
- **No `isUndoing` / `isRedoing`.** Foundation flips these only during
  the closure invocation; observers would see `false→true→false` in the
  same dispatch. No host need today.
- **No `removeAllActions()` Observation API.** Hosts that need this
  call `editor.undoManager.removeAllActions()`; the Checkpoint
  notification handles the tickle.
- **No Linux change.** `DiagramKitInteractive` is Apple-only per
  CLAUDE.md. The shims live behind the same platform gate.

## Architecture

`DiagramEditor` is already `@MainActor @Observable`. Add four
read-only Observation-tracked computed properties plus a tickle counter
that NotificationCenter increments:

```swift
@ObservationIgnored
private var _undoStateTickle: UInt64 = 0

@ObservationIgnored
private var _undoObservers: [NSObjectProtocol] = []

public var canUndo: Bool {
    _ = _undoStateTickle
    return undoManager.canUndo
}

public var canRedo: Bool {
    _ = _undoStateTickle
    return undoManager.canRedo
}

public var undoActionName: String {
    _ = _undoStateTickle
    return undoManager.undoActionName
}

public var redoActionName: String {
    _ = _undoStateTickle
    return undoManager.redoActionName
}
```

The `_ = _undoStateTickle` read inside each computed property makes the
`@Observable` macro register a dependency on the counter. Mutating the
counter from the notification observer is what fires Observation
change notifications.

## NotificationCenter wiring

In `init`, after constructing `undoManager`, register observers for
four UndoManager notifications, **scoped to this editor's manager via
the `object:` parameter** so two `DiagramEditor` instances do not
cross-tickle:

| Notification | Fires on |
|---|---|
| `.NSUndoManagerDidUndoChange` | After `undoManager.undo()` returns |
| `.NSUndoManagerDidRedoChange` | After `undoManager.redo()` returns |
| `.NSUndoManagerDidCloseUndoGroup` | After every implicit/explicit group close — covers mutations registered via `registerUndo(withTarget:handler:)` |
| `.NSUndoManagerCheckpoint` | When undo state checkpoints; catches `removeAllActions()` and edge cases |

Each observer is registered via
`NotificationCenter.default.addObserver(forName:object:queue:.main, using:)`
which returns an opaque token. Store the four tokens in
`_undoObservers`. The closure does one job:

```swift
_undoObservers.append(
    NotificationCenter.default.addObserver(
        forName: .NSUndoManagerDidCloseUndoGroup,
        object: undoManager,
        queue: .main
    ) { [weak self] _ in
        MainActor.assumeIsolated {
            self?._undoStateTickle &+= 1
        }
    }
)
```

`MainActor.assumeIsolated` is required under Swift 6 strict
concurrency — the closure signature is `@Sendable (Notification) ->
Void`; the queue is `.main`; the editor is `@MainActor`, so the
isolation assumption holds.

## Cleanup

In `deinit`, remove every observer:

```swift
deinit {
    for token in _undoObservers {
        NotificationCenter.default.removeObserver(token)
    }
}
```

`@MainActor` deinit is non-isolated under Swift 6, but
`NotificationCenter.removeObserver(_:)` is documented thread-safe, so
the non-isolated deinit is correct. **Verify with a small spike before
committing** — if the deinit hits any isolated state we missed, fall
back to a manual `tearDownObservers()` method that the playground
calls before dropping its editor reference (matches the existing
`applySeededEditor` lifecycle).

## Playground migration (same PR)

Once the library shims land, delete the workaround:

### `Examples/DiagramPlayground/Models/LiveEditorStore.swift`

- **Lines 132-143**: delete the `_undoTickle` storage and the
  three-line comment block above it.
- **Lines 144-159**: delete `canUndoStructural`, `canRedoStructural`,
  `undoStructuralActionName` computed properties.
- **Lines 161-163**: delete the private `_bumpUndoTickle()` helper.
- **Line 454**: delete the `_bumpUndoTickle()` call after the editor
  swap. The new editor's NotificationCenter observers pick up its
  fresh state automatically — but the old editor's *Observation* was
  on the old instance; SwiftUI re-subscribes when the binding source
  changes, so no manual nudge needed.
- **Lines 892-901**: delete `_bumpUndoTickle()` calls inside
  `undoStructural()` and `redoStructural()`. The
  `NSUndoManagerDidUndoChange` and `NSUndoManagerDidRedoChange`
  observers fire automatically.

### `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`

- **Line 490**: `.disabled(!store.canUndoStructural)` →
  `.disabled(!(store.editor?.canUndo ?? false))`
- **Line 497**: `.disabled(!store.canRedoStructural)` →
  `.disabled(!(store.editor?.canRedo ?? false))`

### Other call sites

Grep for `canUndoStructural`, `canRedoStructural`,
`undoStructuralActionName` before committing. Any reads outside
`LiveEditorStore` rewrite to `store.editor?.canUndo ?? false` /
`store.editor?.canRedo ?? false` /
`store.editor?.undoActionName ?? ""`. The grep at design time
showed only the two `DiagramEditorPane` callsites above plus the
declaring file itself.

`Examples/DiagramPlayground/DiagramPlaygroundApp.swift:71, 81`
already reads `editor.undoManager.canUndo` directly inside the
Cmd-Z/Cmd-Shift-Z handlers. That pattern stays correct — it's a
one-shot read inside an action closure, not a SwiftUI dependency.

## Tests

New file `Tests/DiagramKitTests/DiagramEditorUndoObservationTests.swift`
covering:

1. **Initial state.** Fresh editor → `canUndo == false`,
   `canRedo == false`, `undoActionName == ""`, `redoActionName == ""`.
2. **After mutation.** One `await editor.perform(.insertNode(...))`
   → `canUndo == true`, `undoActionName` non-empty,
   `canRedo == false`.
3. **Direct UndoManager call regression test.**
   `editor.undoManager.undo()` (NOT through any future convenience
   wrapper) → `canUndo == false`, `canRedo == true`,
   `redoActionName` non-empty. This is the load-bearing test for
   the NotificationCenter path — proves consumer-direct calls flow
   through to Observation.
4. **Observation registration.** Wrap the editor in
   `withObservationTracking { _ = editor.canUndo }` and assert the
   change handler fires after a mutation. Use the standard
   swift-testing `confirmation { ... }` pattern.
5. **Multi-editor isolation.** Construct two editors, mutate A,
   assert B's `canUndo` stayed `false`. Validates the `object:`
   scoping on the notification registration.

## Risks

- **Swift 6 strict concurrency.** `MainActor.assumeIsolated` inside
  `@Sendable` notification closures is the documented pattern but
  has tripped subtle bugs in other targets. Run
  `Scripts/strict-concurrency-check.sh` after the wiring lands and
  before the playground migration.
- **deinit observer cleanup.** Covered above. Spike first; fall back
  to manual teardown if needed.
- **CLAUDE.md sync.** Test source count goes 236 → 237. One-line
  edit in the same PR.

## Out of scope

Two REVIEW.md §4 items adjacent to this work that are already closed
and **do not need re-touching**:

- `DiagramEditor.preferredExportFormat` was migrated from `let` to
  `var` in Session 2's `57a33da`.
- `requestRender(reason:)` already clears `parseError`. The error
  overlay no longer sits atop a fresh render.

Verified during this spec's exploration; left here so reviewers can
see the boundary.

## Sequencing

One commit per logical step, on `main` per the project's standing
default. Anticipated commits:

1. Add the four computed properties + `_undoStateTickle` storage on
   `DiagramEditor`. No observers yet → tests at step 4 will fail.
2. Add NotificationCenter observer registration in `init` + deinit
   cleanup. The four new tests now pass.
3. Add the test file (could be earlier under TDD — see plan).
4. Playground migration: delete `LiveEditorStore` workaround, rewrite
   two `DiagramEditorPane` callsites.
5. CLAUDE.md test source count sync.

The exact TDD ordering (test file first vs. implementation first)
belongs in the implementation plan, not this spec. This document
specifies *what* lands; the plan specifies *how*.
