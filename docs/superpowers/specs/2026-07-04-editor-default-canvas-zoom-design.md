# Editor Default Mode + Unified Canvas Zoom

**Date:** 2026-07-04
**Status:** Approved design
**Scope:** `Sources/DiagramKitSample/` (the DiagramPlayground sample app). No
library or corpus-snapshot changes.

## Summary

Two coupled changes to the DiagramKitSample playground:

1. **Default the workspace to the "Editor" (visual) mode** instead of Split, so
   a fresh launch lands on the visual editing canvas.
2. **Give the visual editing canvases real zoom/pan** and unify the zoom/pan
   implementation so the preview and editor share one gesture + toolbar +
   coordinate model (with *independent* zoom/pan values per surface).

The requests are coupled: today zoom is complete only in the preview canvas
(`PreviewCanvas`), while the visual editing canvases (`FlowchartEditCanvas`,
`GanttEditCanvas`, `SequenceEditCanvas`) have none. Making Editor the default
without adding zoom there would land users on a canvas that cannot zoom.

## Current State (as of this design)

- `WorkspaceMode` (`Models/Workspace/WorkspaceMode.swift`) has `.code` / `.visual`
  (labeled **"Editor"**) / `.split`; `WorkspaceMode.default == .split`. The
  default flows into `LiveEditorState.init(workspaceMode:)` and the decode
  fallback (`LiveEditorState.swift`). No test pins the `.split` default.
- Regular (iPad/macOS) layout: `PlaygroundShell.bodyForMode` switches on
  `store.state.workspaceMode` — `.code` → `EditorPane`, `.split` →
  `EditorPane + PreviewCanvas`, `.visual` → `VisualPane`.
- Compact (iPhone) layout: `LiveEditorView.compactLayout` uses a separate
  Edit/View/Inspect picker; there is no visual pane. Out of scope for the
  "Editor default" change.
- `PreviewCanvas` owns a complete zoom implementation: `MagnificationGesture`
  (pinch), `DragGesture` (pan), `PreviewToolbar` (Fit / − / % / + / 1:1 / pan
  toggle / grid / full-window), Cmd `0`/`-`/`=`/`1` shortcuts, min 0.25 / max
  4.0, persisted via `store.state.zoomScale` + `store.state.panOffset`.
- The visual canvases have **no zoom**. `FlowchartEditCanvas` centers a
  `DiagramView` at the view center (no scale) and maps hit-testing through
  `diagramPoint(from:viewSize:)` / `viewRect(for:in:)`, which assume scale = 1
  and offset = 0. `store.state.visualTool` already has a `.pan` case that is
  currently a no-op.

## Part A — Default workspace mode → Editor

- Change `WorkspaceMode.default` from `.split` to `.visual` in
  `WorkspaceMode.swift`. Fresh launch / cleared state opens on **Editor**;
  users with a persisted mode keep it (decode preserves stored values).
- Leave the compact iPhone layout untouched — it has no visual pane and its
  picker is a distinct Edit/View/Inspect concept.
- **Unsupported-family fallback:** `VisualPane` only has editors for
  flowchart/state, sequence, and gantt; other families fall back to a
  read-only `DiagramView`. Wrap that fallback in the shared zoom container
  (Part B) so Editor mode always supports zoom/pan regardless of family.

## Part B — Unified zoom/pan model

### 1. `CanvasTransform` — pure, unit-tested value type

A struct `{ scale: CGFloat, offset: CGSize }` centralizing the
centering + scale + offset math currently duplicated between `PreviewCanvas`
and `FlowchartEditCanvas`. Pure helpers:

- `viewRect(forDiagramBounds:viewSize:)` — diagram-space rect → view-space rect.
- `diagramPoint(fromViewPoint:viewSize:)` — inverse of the above (for
  hit-testing).
- `fitScale(diagramBounds:viewSize:)` — the ~0.92-margin fit calculation.
- `clampedScale(_:)` — clamp to `minZoom`/`maxZoom` (0.25 / 4.0).

These are pure functions with no SwiftUI dependency, so hit-testing-under-zoom
is verifiable without the UI.

### 2. Shared `ZoomableCanvas` container + generalized toolbar

- Extract today's `PreviewToolbar` into a reusable `CanvasZoomToolbar` (the
  editor uses a trimmed cluster: Fit / − / % / + / 1:1; the preview keeps its
  grid + full-window extras via optional parameters).
- A `ZoomableCanvas` container view owns the interaction layer:
  - Pinch via `MagnificationGesture`.
  - Pan via drag-on-empty-space and (macOS) trackpad two-finger scroll.
  - (macOS) ⌘ + scroll → zoom.
  - Hosts the floating toolbar.
- The container is **state-source-agnostic**: it takes `zoomScale` and
  `panOffset` bindings plus the diagram bounds. It does not know which surface
  it drives.

### 3. Independent per-surface state

- Preview keeps `state.zoomScale` / `state.panOffset`.
- Add `state.visualZoomScale: CGFloat?` and `state.visualPanOffset: CGSize?` to
  `LiveEditorState` (Codable, `decodeIfPresent` with nil default). Add
  `setVisualZoomScale(_:)` / `setVisualPanOffset(_:)` to `LiveEditorStore`
  mirroring the existing preview setters.
- Preview binds the preview values; the editor binds the visual values — same
  component, separate values, no cross-jump when switching modes in Split.

### 4. Editor-canvas integration

- `FlowchartEditCanvas` routes all coordinate math through a `CanvasTransform`
  built from the visual zoom/pan state:
  - `DiagramView` frame scales by `scale`; centering position shifts by
    `offset`.
  - `diagramPoint(from:)` / `viewRect(for:)` delegate to the transform so tap,
    double-tap, marquee, connector drag, node-drag, image overlays, selection
    handles, and subgraph overlays stay pixel-correct under zoom.
  - Drag starting on empty space → pan (wire the existing `.pan` visualTool
    path and the select-tool empty-drag); drag starting on a node → unchanged
    move/select.
- Apply the same `CanvasTransform` + `ZoomableCanvas` wrapping to
  `GanttEditCanvas` and `SequenceEditCanvas`, and to the `VisualPane`
  read-only fallback `DiagramView`.

### Interactions delivered (both surfaces)

- Pinch-to-zoom.
- Drag empty space to pan.
- (macOS) trackpad two-finger scroll to pan; ⌘ + scroll to zoom.
- Keyboard: ⌘ `=` zoom in, ⌘ `-` zoom out, ⌘ `0` fit, ⌘ `1` actual size.
- On-canvas control cluster: Fit / − / % / + / 1:1 (preview additionally keeps
  grid + full-window).

## Testing & Verification

- **Unit tests** for `CanvasTransform`: view↔diagram point round-trip at
  several scales/offsets, `fitScale` for representative bounds/viewport pairs,
  and `clampedScale` boundaries. Add under `Tests/DiagramKitTests/`, alongside
  the existing `TapCoordinateConversionTests.swift` (that target already
  `@testable import`s `DiagramKitSample`, so `CanvasTransform` is reachable).
- **No corpus snapshot changes** — the sample app is an executable target,
  outside the `CorpusSnapshotTests` gate. No rebaseline.
- **Manual verification** via `swift run DiagramKitSample`: confirm the app
  opens on Editor, and that pinch / drag-pan / keyboard / toolbar zoom all work
  on both the editor canvas and the Split preview, with independent values.

## Non-Goals

- No changes to the library targets or public API.
- No change to the compact iPhone layout's mode picker.
- No shared (linked) zoom values between preview and editor — explicitly
  independent per surface.

## Risks / Notes

- Threading `CanvasTransform` through `FlowchartEditCanvas` touches every
  coordinate helper; the pure-struct unit tests are the guardrail against
  hit-testing drift.
- `FlowchartEditCanvas` is already ~480 lines; extracting the transform and
  the shared container helps keep it under the file-size gate rather than
  growing it.
