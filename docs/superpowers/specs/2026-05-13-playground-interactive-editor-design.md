# Playground: Interactive Editor Integration — Design

**Status:** Approved through brainstorming · ready for writing-plans
**Date:** 2026-05-13
**Scope:** `Examples/DiagramPlayground/` and `Sources/DiagramKitViews/`

## Background

`DiagramKitInteractive` ships a `DiagramEditor` that owns a `DiagramDocument`, an undo/redo stack, and structured mutations (`setTitle`, `setLabel`, `deleteElement`, plus flowchart-specific `insertNode` / `insertEdge`). The playground already depends on the module and has a modal `InspectorView` that wires `setTitle` / `setLabel` / `deleteElement` / undo / redo, but the integration is transient (the editor is recreated on every sheet open), limited (no insert UX, no canvas selection), and decoupled from the live preview.

This design replaces the modal Inspector with a persistent, canvas-driven editing pane that co-owns state with `LiveEditorStore`, surfaces every public `DiagramEditor` mutation, and lets users select elements by tapping the preview.

## Decisions

| Decision | Choice |
| --- | --- |
| Scope | Full canvas-driven editing |
| State model | Text-canonical; store re-seeds a persistent `DiagramEditor` on every successful parse |
| Layout placement | Floating Inspector drawer over the preview, Cmd-I toggle |
| Family coverage | Flowchart only (banner for everything else) |
| Selection adornment | 2pt accent-color outline ring around the selected element |
| API boundary | Add a public `boundsLookup` binding to `DiagramView` |
| Implementation approach | Replace `InspectorView` with a fresh `DiagramEditorPane`; remove the modal sheet |

## Architecture & data flow

```
   text edits                                          tap on preview
   in editor                                           (with pan/zoom)
       │                                                       │
       ▼                                                       ▼
┌──────────────────────────────────────────────────────────────────────┐
│                       LiveEditorStore (@MainActor)                   │
│                                                                      │
│   state.source ───► debounced re-seed ─────────────────┐             │
│                                                        ▼             │
│                                                ┌───────────────┐     │
│                                                │ DiagramEditor │     │
│                                                │  (persistent) │     │
│                                                │   document    │     │
│                                                │   selection   │     │
│                                                │   undoManager │     │
│                                                └──────┬────────┘     │
│                                                       │              │
│                          structural mutations  ◄──────┤              │
│                          push exported source         │              │
│                          back into state.source       │              │
└───────────────────────────────────────────────────────┼──────────────┘
                                                        │
                                                        ▼
                                              ┌──────────────────┐
                                              │   PreviewCanvas  │
                                              │   ┌────────────┐ │
                                              │   │ DiagramView│ │
                                              │   └─────┬──────┘ │
                                              │         │        │
                                              │   publishes      │
                                              │   parseError,    │
                                              │   diagramBounds, │
                                              │   boundsLookup   │
                                              │                  │
                                              │  Selection       │
                                              │  overlay         │
                                              │  (accent ring)   │
                                              └──────────────────┘
```

**Single source of truth: `state.source`.** Every structural mutation exports back into `state.source`, which re-triggers the normal render path. There is no separate "structural update" channel into the preview.

**Editor lifecycle.** `LiveEditorStore` owns one persistent `DiagramEditor?`. On every successful parse the store re-seeds the editor's `document`, `preferredExportFormat`, and `source`. If the previously selected element ID still resolves in the new lookup, selection is restored; otherwise it is cleared silently. Structural undo is reset on every text-edit-triggered re-seed — text edits are the ground truth, not undoable through the structural stack. Structural undo only covers runs of structural mutations between text edits.

**Tap path.** `PreviewCanvas` receives a `TapGesture` location, converts view-coords → diagram-coords using the committed `state.zoomScale` and `state.panOffset` plus the centering offset of the framed `DiagramView`, calls `store.boundsLookup?.element(at:)`, and sets `editor.selection`. The same lookup feeds the accent-outline overlay.

**API addition.** `DiagramView` gains a `boundsLookup: Binding<DiagramBoundsLookup?>` that publishes from the existing `prepareCompletion` hook, reading `view.diagramLayer.preparedDiagram?.positioned.lookup`.

## Components

### 1. `Sources/DiagramKitViews/DiagramView.swift` — API addition

```swift
@Binding private var boundsLookup: DiagramBoundsLookup?

public init(
    source: String,
    theme: DiagramTheme = .default,
    layoutConfig: LayoutConfig = LayoutConfig(),
    parseError: Binding<Error?> = .constant(nil),
    diagramBounds: Binding<CGRect> = .constant(.zero),
    boundsLookup: Binding<DiagramBoundsLookup?> = .constant(nil)
)
```

Plumbed through both the UIKit and AppKit variants. `Coordinator.publish(from:)` is extended to publish `view.diagramLayer.preparedDiagram?.positioned.lookup`. Default `.constant(nil)` keeps all existing call sites compiling without changes. No deprecations introduced.

### 2. `Examples/DiagramPlayground/Models/LiveEditorStore.swift` — extensions

New stored state:

- `var editor: DiagramEditor?` — persistent, re-seeded on every successful parse.
- `var boundsLookup: DiagramBoundsLookup?` — mirrors what `DiagramView` publishes.
- `var inspectorOpen: Bool = false` — drives the drawer overlay; persisted via `LiveEditorState`.

New actions:

- `setSelection(_:)` — single entry point for canvas taps and the picker menu.
- `performMutation(_:)` / `performFlowchartMutation(_:)` — wrap `editor.perform(...)` / `editor.performFlowchart(...)`, push the exported source back into `state.source` via `setSource(_, origin: .system)`, and surface errors as a pane-local banner.
- `toggleInspector()` — flips `inspectorOpen`.
- `undoStructural()` / `redoStructural()` — delegate to `editor?.undoManager`.

Re-seed logic lives in `didCompleteRender(...)` (or a private `seedEditorFromSource(...)` invoked from there). Selection by element ID is preserved when possible; otherwise cleared.

### 3. New `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`

Replaces the modal `InspectorView`. Sections in order:

- **Header** — title + close button (`store.toggleInspector()`). If `editor == nil`, shows "Parse to enable interactive editing"; if document type ≠ flowchart, shows "Interactive editing not yet available for *<type>*."
- **Title** — TextField bound to a draft; "Set" / "Clear" → `.setTitle(_:)`.
- **Selection** — shows the current element's label and kind (node vs edge). Picker menu (grouped by Nodes / Edges) acts as a keyboard fallback when the canvas has no selection.
- **Label** — TextField + "Rename" → `.setLabel(of:to:)`.
- **Insert (flowchart-only, new)**:
  - *Insert node* — ID, Label, shape `Picker` (rectangle / round / stadium / circle / rhombus), "Insert" → `.insertNode(...)`. Generates a unique default ID (`n1`, `n2`, ...) when blank.
  - *Insert edge* — `from` / `to` pickers built from the lookup, optional label, "Insert" → `.insertEdge(...)`. Defaults `from` to the current selection if it is a node.
- **Delete** — "Delete selected" → `.deleteElement(_:)`, disabled when no selection.
- **Undo / Redo footer** — buttons + last action name + inline `editor.lastExportDiagnostics`.

The pane intentionally has no source-preview section — the adjacent text editor already serves that role.

### 4. `Examples/DiagramPlayground/Views/PreviewCanvas.swift` — changes

- Pass `boundsLookup: $liveBoundsLookup` to `DiagramView`; mirror the value into `store.boundsLookup` (analogous to existing `parseError` / `diagramBounds` plumbing).
- Add a `TapGesture` on the diagram content that:
  - Converts the tap location to diagram coordinates by undoing the current `effectivePanOffset`, `currentZoomScale`, and centering offset of the `.frame(width: scaledWidth, height: scaledHeight)`.
  - Calls `store.boundsLookup?.element(at: localPoint)` → on hit, `store.setSelection(lookup.selection(for: elementID))`; on miss, clears selection.
  - Uses `.simultaneousGesture` and is suppressed while a magnification or drag gesture is in progress.
- Add a SwiftUI overlay that, when `editor.selection != nil` and `boundsLookup` has bounds for the selected ID, draws a 2pt `theme.effectiveAccent()` `RoundedRectangle` at the element's bounds, transformed by the same zoom/pan. Edges are outlined by their bounding rect.

### 5. `Examples/DiagramPlayground/Views/LiveEditorView.swift` — changes

- Wrap `editorPreviewSplit` in a `ZStack` that overlays `DiagramEditorPane` on the right side of the preview when `store.inspectorOpen == true`, with `.transition(.move(edge: .trailing))`.
- Add a `CommandGroup(replacing: .undoRedo)` block (macOS only) that delegates to `store.undoStructural()` / `store.redoStructural()` *only when* the inspector is the focused surface and `editor?.undoManager.canUndo == true`. Falls through to the responder chain otherwise. Focus tracked via `@FocusState`.
- Compact iPhone treatment: add `CompactMode.inspector`, so the segmented picker becomes Edit / View / Inspect; `.inspector` mode fills the screen instead of overlaying.

### 6. `Examples/DiagramPlayground/Views/Toolbar/LiveEditorToolbar.swift` — toolbar button

Add an "Inspector" toolbar button: `slider.horizontal.below.rectangle`, `.keyboardShortcut("i", modifiers: [.command])`, action `store.toggleInspector()`. Toggle state mirrors `store.inspectorOpen`.

### 7. `Examples/DiagramPlayground/Views/ActionsView.swift` — cleanup

Remove the "Inspector" action button under the "View" section and the `onShowInspector` closure parameter. `ActionsPanel` loses its `.sheet(isPresented: $showingInspector)` block and the `@SwiftUI.State` flag. The "View" section now contains only "Full-Window Preview".

### 8. Deletions

- `Examples/DiagramPlayground/Views/Inspector/InspectorView.swift` — deleted.
- `Examples/DiagramPlayground/Views/Inspector/` directory removed once empty.

### 9. `Examples/DiagramPlayground/Models/LiveEditorState.swift`

Add `var inspectorOpen: Bool = false`. Threaded through `LiveEditorStateCodec` encode/decode (missing key decodes as `false`) and `LiveHistoryEntry` save/restore.

## Error handling & edge cases

- **Parse failure on text edit** — re-seed is skipped; `editor` retains its previous value with selection cleared. Pane shows "Source has a parse error — fix the source to resume editing." Mutation buttons disabled.
- **`DiagramEditorError`** caught in `performMutation`:
  - `.notAFlowchart` — gated up-front; unreachable, reported via `IssueReporting.reportIssue` if it ever fires.
  - `.duplicateNodeID` — surfaces inline next to the Insert-Node ID field.
  - `.elementNotFound` — selection clears; banner says "Selected element no longer exists."
  - `.sourceSyncFailed(underlying:)` — surfaced in banner; editor's atomic-commit contract guarantees no partial state.
- **Tap with stale or missing lookup** — `boundsLookup == nil` makes taps a no-op; tap on empty space clears selection; an element ID the editor doesn't recognize is reported and selection is cleared.
- **Re-seed race** — mutations and `didCompleteRender` are both `@MainActor`; serialise cleanly. Mutation → `setSource(origin: .system)` → re-seed is idempotency-guarded (`state.source != source`).
- **Selection survival** — preserved across re-seed when the element ID still resolves; silently cleared otherwise.
- **Pan/zoom interaction** — tap recognition suppressed while a gesture is in flight (`gestureBaseZoomScale != nil` or active drag). Overlay uses committed zoom/pan only.
- **iPhone compact-mode** — Cmd-I and `CommandGroup` overrides are macOS-only; iPhone uses the segmented mode picker and an explicit undo button in the pane.
- **Cmd-Z routing** — `CommandGroup(replacing: .undoRedo)` only intercepts when the inspector is focused *and* structural undo has work; otherwise the text editor's native undo continues to work. Focus tracked via `@FocusState` (`.text` vs `.inspector`).
- **API backwards compatibility** — `boundsLookup` defaults to `.constant(nil)`; all existing `DiagramView` call sites compile unchanged.

## Testing

### Library-level (`Tests/DiagramKitTests/`)

1. **`DiagramViewBoundsLookupBindingTests`** (Apple-only, swift-testing)
   - Constructs a `DiagramView` with a known flowchart source via the existing prepare path; asserts `boundsLookup` publishes a non-nil lookup whose `allElementIDs` matches expected node/edge IDs.
   - On parse error, asserts the binding receives `nil`.
   - Default-constructed `DiagramView` (no `boundsLookup` binding) compiles and renders — source-compat check via the default parameter.
2. **No new corpus snapshots needed** — the binding is read-only and does not change geometry. Running `swift test --filter CorpusSnapshotTests` (chunked per the [Avoid full `swift test` runs] memory) should be byte-identical.

### Playground-level

Playground sources live in `Examples/DiagramPlayground/` and depend on SwiftUI, AppKit/UIKit, and `BMImage` — they cannot be exercised from `Tests/DiagramKitTests/` (which only sees the SwiftPM library targets) and cannot be exercised by Linux `swift test`. To unit-test the new orchestration we add a new xcodeproj test target.

3. **New `DiagramPlaygroundTests` target** — added to `Examples/DiagramPlayground/project.yml` as a `bundle.unit-test` target on the macOS scheme. Tests live under `Examples/DiagramPlayground/Tests/`. Run via `xcodebuild test -scheme DiagramPlayground -destination 'platform=macOS'`. The smoke check (`Scripts/bootstrap-smoke-check.sh`) already invokes `xcodebuild` for the playground; we extend that step to also run the test action.
4. **`LiveEditorStoreEditorLifecycleTests`** in the new target (XCTest, `@MainActor` cases):
   - `editor` is `nil` for an empty source.
   - After `setSource(...)` with valid flowchart Mermaid: `editor != nil`, `editor.document.type == .flowchart`, `editor.preferredExportFormat == state.sourceFormat.formatID`.
   - After `setSource(...)` with a parse error: `editor` retains its prior value (or stays `nil`); `parseError != nil`.
   - `performMutation(.setLabel(...))` updates `state.source` to the exported source; selection by element ID is preserved across the re-seed.
   - `performMutation(.deleteElement(...))` on the selected element clears `editor.selection` after re-seed.
   - `inspectorOpen` round-trips through `LiveEditorStateCodec.encode`/`decode` and through history save/restore.
5. **Tap-coordinate conversion** is structured as a pure static function so it can be unit-tested without SwiftUI:

   ```swift
   static func tapPointInDiagramCoordinates(
       viewPoint: CGPoint,
       viewSize: CGSize,
       diagramBounds: CGRect,
       zoomScale: CGFloat,
       panOffset: CGSize
   ) -> CGPoint
   ```

   Tested in the new target with three cases: identity transform, zoomed in, panned + zoomed.
6. **Tap-to-select via the store seam.** Feeds a fake `DiagramBoundsLookup` (built via `DiagramBoundsLookup.build(...)`, which is already public) and asserts `store.handleTapAt(_:viewSize:)` either sets the right selection or clears it. SwiftUI gestures are not driven from XCTest.

### Manual verification (`swift run DiagramPlayground`)

- Cmd-I toggles the drawer; pane closes via header button and Cmd-I.
- Tap on a node sets selection; the accent ring tracks the node when source changes and during pan/zoom.
- Tap on empty space clears selection.
- Set title / Set label / Delete / Insert node / Insert edge each mutate `state.source` (text editor reflects the new source).
- Cmd-Z with focus in inspector undoes the last structural mutation; Cmd-Z with focus in text editor undoes a text keystroke. Independent stacks.
- Switching the sample to a non-flowchart (e.g. sequence) shows the disabled banner; canvas no longer adornments anything.
- iPhone compact mode shows Edit / View / Inspect tabs.
- Convert / export / history / load actions unaffected.

### Discipline gates (per `CLAUDE.md`)

- `swift build` and `swift build --build-tests` succeed.
- `swift test --filter DiagramViewBoundsLookupBindingTests` passes.
- `xcodebuild test -scheme DiagramPlayground -destination 'platform=macOS'` runs the new `DiagramPlaygroundTests` target green.
- `Scripts/check-file-sizes.sh`, `Scripts/check-sendable-annotations.sh`, `Scripts/strict-concurrency-check.sh` pass. `DiagramEditorPane.swift` stays under the 500-line warning; split into subviews if it grows.
- `Scripts/linux-check.sh` if Docker/Podman available — `DiagramKitViews` is already `#if canImport(UIKit) || canImport(AppKit)`-gated, so Linux compilation is unchanged.
- Playground builds for both macOS and iOS schemes via the `xcodebuild` sweep in `bootstrap-smoke-check.sh`.

## Out of scope

- Insert-node / insert-edge for state diagrams (library doesn't ship flowchart-style helpers for them yet).
- Drag-to-create or drag-to-reposition gestures on the canvas.
- Multi-selection.
- Snapshot baselines for the playground's own UI (no playground snapshot infrastructure exists today).
- Library-level snapshot baselines for the new binding (the binding is data-only).
