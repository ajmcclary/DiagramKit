# DiagramEditor Observation-tracked undo state — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the playground's manual `_undoTickle` undo-observation workaround into `DiagramEditor` itself so any consumer can write `.disabled(!editor.canUndo)` and have SwiftUI re-evaluate correctly.

**Architecture:** `DiagramEditor` (already `@MainActor @Observable`) gains four read-only computed properties (`canUndo`, `canRedo`, `undoActionName`, `redoActionName`) backed by a `@ObservationIgnored` tickle counter. NotificationCenter observers scoped to each editor's `UndoManager` increment the tickle in response to `NSUndoManagerDidUndoChange`, `NSUndoManagerDidRedoChange`, `NSUndoManagerDidCloseUndoGroup`, and `NSUndoManagerCheckpoint`.

**Tech Stack:** Swift 6, `@Observable` macro, `Foundation.UndoManager`, `Foundation.NotificationCenter`, swift-testing, `MainActor.assumeIsolated`, Project standing default: commit-by-commit on `main`.

**Spec:** [`docs/superpowers/specs/2026-05-14-diagrameditor-observation-undo-design.md`](../specs/2026-05-14-diagrameditor-observation-undo-design.md)

---

## File Structure

**Modify:**
- `Sources/DiagramKitInteractive/DiagramEditor.swift` — add four computed properties, `_undoStateTickle` storage, `_undoObservers` storage, observer registration in `init`, and `deinit` cleanup.
- `Examples/DiagramPlayground/Models/LiveEditorStore.swift` — delete workaround (tickle storage, three computed mirrors, helper, three `_bumpUndoTickle()` callsites).
- `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift` — rewrite two `.disabled(...)` callsites at lines 490 and 497.
- `CLAUDE.md` — sync test source count (236 → 237).

**Create:**
- `Tests/DiagramKitTests/Interactive/DiagramEditorUndoObservationTests.swift` — five new tests.

---

## Task 1: Add a single failing test to prove the new surface compiles to a hole

**Goal:** Confirm `canUndo` does not yet exist on `DiagramEditor`. The test file is created with one test only; the rest land in Task 3 after the property surface exists.

**Files:**
- Create: `Tests/DiagramKitTests/Interactive/DiagramEditorUndoObservationTests.swift`

- [ ] **Step 1: Create the test file with the initial-state test**

```swift
// DiagramEditor Observation-tracked undo state tests
//
// Verifies the `canUndo` / `canRedo` / `undoActionName` / `redoActionName`
// computed properties on DiagramEditor pick up UndoManager state changes
// through NotificationCenter, including consumer-direct
// `editor.undoManager.undo()` calls.

import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
import Observation
@testable import DiagramKitInteractive

// MARK: - Shared fixtures

private struct MockExporter: DiagramExporter {
    let name: String = "Mock"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart]

    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        DiagramExportResult(source: "mock:flowchart")
    }
}

private func mockRegistry() -> ExporterRegistry {
    ExporterRegistry.empty.registering(MockExporter())
}

private func flowDoc(_ nodes: [String]) -> DiagramDocument {
    let mNodes = nodes.map { id in
        (id: id, node: original_src_types.MermaidNode(id: id, label: "Node \(id)", shape: .rectangle))
    }
    let model = original_src_types.MermaidGraph(
        direction: .TD,
        nodesInOrder: mNodes,
        edges: []
    )
    return DiagramDocument(payload: .flowchart(model))
}

private func makeEditor(_ nodes: [String] = ["A", "B"]) async throws -> DiagramEditor {
    let editor = DiagramEditor(
        document: flowDoc(nodes),
        preferredExportFormat: .mermaid,
        exportRegistry: mockRegistry()
    )
    try await editor.syncSource()
    return editor
}

// MARK: - Suite

@Suite @MainActor
struct DiagramEditorUndoObservationTests {

    @Test("Fresh editor reports canUndo=false, canRedo=false, both action names empty")
    func initialState() async throws {
        let editor = try await makeEditor()
        #expect(editor.canUndo == false)
        #expect(editor.canRedo == false)
        #expect(editor.undoActionName == "")
        #expect(editor.redoActionName == "")
    }
}
```

- [ ] **Step 2: Build to confirm the test fails to compile**

Run: `swift build --build-tests 2>&1 | tail -20`
Expected: build fails with errors mentioning `value of type 'DiagramEditor' has no member 'canUndo'` (and `canRedo`, `undoActionName`, `redoActionName`).

- [ ] **Step 3: Commit the failing test**

```bash
git add Tests/DiagramKitTests/Interactive/DiagramEditorUndoObservationTests.swift
git commit -m "$(cat <<'EOF'
test(interactive): DiagramEditor canUndo/canRedo initial-state probe

Failing test: DiagramEditor does not yet expose Observation-tracked
canUndo/canRedo/undoActionName/redoActionName. Lands as a compile-time
failure ahead of Task 2.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add the four computed properties + tickle storage

**Goal:** Make the Task-1 test compile and pass. The tickle never bumps yet — that lands in Task 4 — so this task only handles the initial-state path.

**Files:**
- Modify: `Sources/DiagramKitInteractive/DiagramEditor.swift:108-128` (insert new storage near the existing `@ObservationIgnored` fields, add computed properties between `isExporting` and `// MARK: - Initialization`)

- [ ] **Step 1: Add storage and computed properties**

Insert this block immediately before line 111 (`// MARK: - Initialization`) in `Sources/DiagramKitInteractive/DiagramEditor.swift`:

```swift
    // MARK: - Observation-tracked undo state

    /// Tickle counter bumped by NotificationCenter observers when the
    /// undo/redo stack changes state. Reading this counter inside the
    /// computed properties below registers an `@Observable` dependency
    /// so SwiftUI modifiers like `.disabled(!editor.canUndo)` re-evaluate.
    ///
    /// `Foundation.UndoManager` is not Observation-tracked itself, so this
    /// counter is the bridge.
    @ObservationIgnored
    private var _undoStateTickle: UInt64 = 0

    /// Notification observer tokens. Held so `deinit` can release them.
    @ObservationIgnored
    private var _undoObservers: [NSObjectProtocol] = []

    /// True when at least one undoable action is registered.
    /// Observation-tracked; updates as the undo stack changes.
    public var canUndo: Bool {
        _ = _undoStateTickle
        return undoManager.canUndo
    }

    /// True when at least one redoable action is registered.
    /// Observation-tracked; updates as the redo stack changes.
    public var canRedo: Bool {
        _ = _undoStateTickle
        return undoManager.canRedo
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

```

- [ ] **Step 2: Build to confirm the file compiles**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: build succeeds with no errors.

- [ ] **Step 3: Run the Task-1 test**

Run: `swift test --filter DiagramEditorUndoObservationTests/initialState`
Expected: PASS — fresh editor has empty undo/redo stacks, so the property reads return the correct values even without the tickle wiring.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitInteractive/DiagramEditor.swift
git commit -m "$(cat <<'EOF'
feat(interactive): DiagramEditor.canUndo/canRedo/undoActionName/redoActionName

Four Observation-tracked computed properties bridge Foundation.UndoManager
state into DiagramEditor's @Observable surface. Backed by an
@ObservationIgnored _undoStateTickle counter; NotificationCenter wiring
to bump the counter lands in the next commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add the four remaining tests (mutation / direct-call / observation / multi-editor)

**Goal:** Cover the cases the NotificationCenter wiring needs to make pass. After this commit, three of the four new tests fail (initial-state passes from Task 2; the rest fail because the tickle never bumps).

**Files:**
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorUndoObservationTests.swift`

- [ ] **Step 1: Append the four new tests to the suite**

Add these four `@Test` functions to `DiagramEditorUndoObservationTests` (inside the existing `@Suite`):

```swift
    @Test("After one mutation, canUndo=true, undoActionName non-empty, canRedo=false")
    func afterMutation() async throws {
        let editor = try await makeEditor()
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:B")
        try await editor.perform(.deleteElement(sel))

        #expect(editor.canUndo == true)
        #expect(editor.undoActionName.isEmpty == false)
        #expect(editor.canRedo == false)
        #expect(editor.redoActionName == "")
    }

    @Test("Consumer-direct editor.undoManager.undo() flows through to canUndo/canRedo")
    func directUndoManagerCall() async throws {
        let editor = try await makeEditor()
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:B")
        try await editor.perform(.deleteElement(sel))

        // Bypass any future convenience wrapper and call the manager
        // directly. The NotificationCenter path is the only thing that
        // can tickle Observation here.
        editor.undoManager.undo()

        #expect(editor.canUndo == false)
        #expect(editor.canRedo == true)
        #expect(editor.redoActionName.isEmpty == false)
    }

    @Test("withObservationTracking { _ = editor.canUndo } fires after a mutation")
    func observationTrackingFires() async throws {
        let editor = try await makeEditor()

        await confirmation("canUndo observation handler fires") { handlerFired in
            withObservationTracking {
                _ = editor.canUndo
            } onChange: {
                handlerFired()
            }

            let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:B")
            // Synchronous-from-test-perspective via await; the onChange
            // handler runs before this expression completes.
            try? await editor.perform(.deleteElement(sel))
        }
    }

    @Test("Two editors' tickles are isolated (object:-scoped notification)")
    func multiEditorIsolation() async throws {
        let editorA = try await makeEditor(["A", "B"])
        let editorB = try await makeEditor(["X", "Y"])

        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:B")
        try await editorA.perform(.deleteElement(sel))

        // A mutated → A.canUndo flipped.
        #expect(editorA.canUndo == true)
        // B untouched → no tickle leak.
        #expect(editorB.canUndo == false)
    }
```

- [ ] **Step 2: Run the suite to confirm the new tests fail as expected**

Run: `swift test --filter DiagramEditorUndoObservationTests`
Expected: `initialState` PASSES; the other four FAIL — `afterMutation` because `canUndo` reads UndoManager directly and UndoManager *does* have stack state, **but** the tickle never fired so Observation wasn't notified. (`canUndo == true` may actually pass here because the computed property re-reads on each access — but `observationTrackingFires` will definitely fail. Confirm exact failure pattern empirically.)

If `afterMutation`, `directUndoManagerCall`, and `multiEditorIsolation` actually pass despite no observers — that's expected; their assertions read computed properties directly, which always re-read UndoManager. Only `observationTrackingFires` strictly requires the tickle to mutate. The other three guard the *semantics* once wiring is in place and serve as regression tests if someone later removes the computed-property pattern.

- [ ] **Step 3: Commit**

```bash
git add Tests/DiagramKitTests/Interactive/DiagramEditorUndoObservationTests.swift
git commit -m "$(cat <<'EOF'
test(interactive): four more DiagramEditor undo observation tests

afterMutation, directUndoManagerCall, observationTrackingFires,
multiEditorIsolation. observationTrackingFires is the load-bearing test
for the NotificationCenter wiring landing in the next commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Wire NotificationCenter observers + deinit cleanup

**Goal:** Make `observationTrackingFires` pass. Register four observers in `init` scoped to this editor's `UndoManager`; release them in `deinit`.

**Files:**
- Modify: `Sources/DiagramKitInteractive/DiagramEditor.swift` — extend `init`, add `deinit`, add a private helper.

- [ ] **Step 1: Extend `init` to register notification observers**

In `Sources/DiagramKitInteractive/DiagramEditor.swift`, replace the existing `init` (starting at line 118) so the end of its body wires observers. The new `init` body:

```swift
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
```

- [ ] **Step 2: Add the observer-registration helper and `deinit`**

Insert this block between the existing `init(...)` closing brace (line 128) and the `// MARK: - Internal mutation helpers` marker (line 130):

```swift
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
            let token = NotificationCenter.default.addObserver(
                forName: name,
                object: undoManager,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?._undoStateTickle &+= 1
                }
            }
            _undoObservers.append(token)
        }
    }

    deinit {
        // NotificationCenter.removeObserver(_:) is documented thread-safe
        // and our observer tokens are simple Foundation references, so
        // tearing them down from a non-isolated deinit is safe.
        for token in _undoObservers {
            NotificationCenter.default.removeObserver(token)
        }
    }

```

- [ ] **Step 3: Run the full new test suite**

Run: `swift test --filter DiagramEditorUndoObservationTests`
Expected: all five tests PASS. The critical one is `observationTrackingFires` — if it still fails, the `MainActor.assumeIsolated` hop is wrong; check that `queue: .main` actually delivers on the main thread under Swift 6 strict concurrency.

- [ ] **Step 4: Run the existing undo suite to confirm no regression**

Run: `swift test --filter "DiagramEditorUndoTests|DiagramEditorMutationTests|DiagramEditorAsyncExportTests"`
Expected: all green. The new observers should not affect mutation/atomicity semantics — they read-only-tickle.

- [ ] **Step 5: Run strict-concurrency gate**

Run: `Scripts/strict-concurrency-check.sh 2>&1 | tail -5`
Expected: `✓ strict concurrency clean for first-party targets` (or equivalent). If the `[weak self]` Sendable capture trips Swift 6, fall back to a non-capturing closure pattern (split observer registration into a free function that takes `weak self` indirectly) — but the documented pattern should work.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitInteractive/DiagramEditor.swift
git commit -m "$(cat <<'EOF'
feat(interactive): NotificationCenter wiring for DiagramEditor undo Observation

Subscribes to NSUndoManagerDidUndoChange / DidRedoChange /
DidCloseUndoGroup / Checkpoint scoped to this editor's UndoManager.
Each notification bumps _undoStateTickle, which canUndo / canRedo /
undoActionName / redoActionName all read — bridging Foundation's
non-Observation-tracked UndoManager into @Observable change tracking.

Catches consumer-direct editor.undoManager.undo() calls, not just
library-mediated mutations.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Migrate the playground off the workaround

**Goal:** Delete `LiveEditorStore`'s `_undoTickle` + three computed mirrors + helper + three callsites. Rewrite the two `DiagramEditorPane` `.disabled(...)` modifiers to read from `editor` directly.

**Files:**
- Modify: `Examples/DiagramPlayground/Models/LiveEditorStore.swift` — delete lines 132-163 (tickle + mirrors + helper) and three `_bumpUndoTickle()` callsites (~454, ~894, ~900).
- Modify: `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift` — rewrite the two `.disabled(...)` modifiers at lines 490 and 497.

- [ ] **Step 1: Grep for any callsites of the soon-to-be-deleted symbols**

Run: `grep -rn "canUndoStructural\|canRedoStructural\|undoStructuralActionName\|_bumpUndoTickle\|_undoTickle" Examples/ Sources/ Tests/`
Expected: hits in `LiveEditorStore.swift` (declarations + 3 call sites) and `DiagramEditorPane.swift` (2 `.disabled` modifiers). If anything appears outside these two files, add a rewrite step here before deleting.

- [ ] **Step 2: Delete the workaround in `LiveEditorStore.swift`**

Open `Examples/DiagramPlayground/Models/LiveEditorStore.swift` and:

**Delete lines 132-163** (the comment block + `_undoTickle` storage + three computed mirrors + `_bumpUndoTickle()` helper). The block to remove starts with `/// Tickle counter that bumps every time` and ends with the closing `}` of `_bumpUndoTickle()`. The next line should be `/// Mirrors what \`DiagramView\` publishes for the current preview source.`

**Delete the `_bumpUndoTickle()` call at line ~454** — the one right after `editor = newEditor` and the comment `// Editor swap → fresh UndoManager → canUndo/canRedo just flipped.`. Delete both the comment and the call:

Before:
```swift
        editor = newEditor
        // Editor swap → fresh UndoManager → canUndo/canRedo just flipped.
        _bumpUndoTickle()
    }
```

After:
```swift
        editor = newEditor
    }
```

**Delete the `_bumpUndoTickle()` calls inside `undoStructural()` and `redoStructural()`** (~894, ~900):

Before:
```swift
    /// Delegate to `editor.undoManager.undo()`.
    public func undoStructural() {
        editor?.undoManager.undo()
        _bumpUndoTickle()
    }

    /// Delegate to `editor.undoManager.redo()`.
    public func redoStructural() {
        editor?.undoManager.redo()
        _bumpUndoTickle()
    }
```

After:
```swift
    /// Delegate to `editor.undoManager.undo()`. Observation updates
    /// flow through `DiagramEditor.canUndo` / `canRedo` via the
    /// NotificationCenter wiring on the editor.
    public func undoStructural() {
        editor?.undoManager.undo()
    }

    /// Delegate to `editor.undoManager.redo()`.
    public func redoStructural() {
        editor?.undoManager.redo()
    }
```

- [ ] **Step 3: Rewrite the `.disabled(...)` modifiers in `DiagramEditorPane.swift`**

Open `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`:

**Line 490** — change:
```swift
.disabled(!store.canUndoStructural)
```
to:
```swift
.disabled(!(store.editor?.canUndo ?? false))
```

**Line 497** — change:
```swift
.disabled(!store.canRedoStructural)
```
to:
```swift
.disabled(!(store.editor?.canRedo ?? false))
```

- [ ] **Step 4: Build to confirm nothing else references the deleted symbols**

Run: `swift build 2>&1 | tail -10`
Expected: build succeeds. If errors mention `canUndoStructural`, `canRedoStructural`, `undoStructuralActionName`, or `_bumpUndoTickle`, return to Step 1 and rewrite the additional callsite.

- [ ] **Step 5: Run the playground/store test suites**

Run: `swift test --filter "LiveEditorStoreEditorLifecycle|LiveEditorConfig|LiveEditorState"`
Expected: all green.

- [ ] **Step 6: Smoke-test the playground manually (Apple only)**

Run: `swift run DiagramPlayground` (or open the Xcode workspace and run on iOS / macOS)
Manual checks (~30 seconds):
- Type a diagram source → undo/redo buttons in the toolbar (`DiagramEditorPane` lines 490/497) start disabled.
- Click an Insert Node button → undo button becomes enabled.
- Click undo → undo button greys out, redo button becomes enabled.
- Click redo → undo becomes enabled again.

If any state transition does not re-evaluate the `.disabled(...)` modifier, the NotificationCenter wiring is incomplete; return to Task 4.

- [ ] **Step 7: Commit**

```bash
git add Examples/DiagramPlayground/Models/LiveEditorStore.swift Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift
git commit -m "$(cat <<'EOF'
refactor(playground): drop _undoTickle workaround; read editor.canUndo directly

LiveEditorStore loses _undoTickle, canUndoStructural, canRedoStructural,
undoStructuralActionName, and _bumpUndoTickle(). The two DiagramEditorPane
.disabled(...) modifiers read store.editor?.canUndo / canRedo directly
now that DiagramEditor's Observation-tracked properties cover the case.

Closes the last open §4 playground item from REVIEW.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Sync CLAUDE.md test source count

**Goal:** Bump the documented test source count to reflect the new test file.

**Files:**
- Modify: `CLAUDE.md` — single number change in the "Testing And Snapshots" section.

- [ ] **Step 1: Confirm the current count**

Run: `find Tests/DiagramKitTests -name '*.swift' | wc -l`
Expected: `237` (or whatever the new total is — read the actual output).

- [ ] **Step 2: Update the line in CLAUDE.md**

Find the line `- Current test source count: 244 Swift files under \`Tests/DiagramKitTests\`.` and update the number to match the actual count from Step 1.

Note the spec referenced "236 → 237" but Session 10's docs may have already shifted the count. **Trust the `find` output, not the spec.**

- [ ] **Step 3: Run the full discipline gates one more time**

```bash
Scripts/check-file-sizes.sh 2>&1 | tail -5
Scripts/check-sendable-annotations.sh 2>&1 | tail -5
```
Expected: both ✓ green (or only pre-existing yellow warnings).

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(claude): sync test source count after undo-observation test add

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review (already run; notes for the executor)

- **Spec coverage:** All four spec sections (Architecture, NotificationCenter wiring, Playground migration, Tests) map to tasks 2/4/5 and the test file in tasks 1/3.
- **Type consistency:** Property names `canUndo`, `canRedo`, `undoActionName`, `redoActionName` are used identically in spec, task 2, task 3 tests, and task 5 callsite rewrites. Internal storage names `_undoStateTickle` and `_undoObservers` are consistent across tasks 2 and 4.
- **Sequencing trade-off**: Tasks 2 and 3 split implementation and observer wiring across two commits because the observer wiring is the load-bearing change for `observationTrackingFires`. Some teams prefer collapsing 2+4 into one commit; if so, run tests after both blocks land instead of after each.

---

## Risks worth re-checking at execution time

- **Swift 6 strict concurrency on the observer closure.** Step 5 of Task 4 runs `Scripts/strict-concurrency-check.sh`. If it fails, the fallback is to extract a small helper:

  ```swift
  @MainActor
  private func _bumpUndoTickle() {
      _undoStateTickle &+= 1
  }
  ```
  …and have the closure call `Task { @MainActor in await self?._bumpUndoTickle() }` instead of `MainActor.assumeIsolated`. This is slower but always-safe. Try the assumeIsolated form first.

- **Notification name collisions.** All four notifications are well-documented Foundation symbols. There is no possibility of a name change between Apple SDK versions in this band.

- **Re-entrancy in `observationTrackingFires`.** swift-testing's `confirmation` blocks complete only after the inner closure does; the `await editor.perform(...)` inside it must finish before the test exits. If the test flakes (handler not called), the cause is likely the async hop in `perform` racing the notification dispatch — increase the expected count or split into two sequential mutations.

- **Deinit cleanup correctness.** `removeObserver(_:)` with the `forName:` API requires passing the token. We hold tokens in `_undoObservers`. There is no leak.
