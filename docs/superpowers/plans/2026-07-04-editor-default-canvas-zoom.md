# Editor Default Mode + Unified Canvas Zoom Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the DiagramKitSample playground open on the visual "Editor" mode by default, and give the visual editing canvases full zoom/pan built on a shared, unit-tested coordinate model and a shared floating toolbar.

**Architecture:** Extract the centering+scale+offset math that already lives in `LiveEditorStore.tapPointInDiagramCoordinates(...)` into a pure `CanvasTransform` value type (forward `viewRect`, inverse `diagramPoint`, `fitScale`, `clampScale`, gesture-scale). Generalize `PreviewToolbar` into a reusable `CanvasZoomToolbar`. Add independent per-surface zoom/pan state (`visualZoomScale`/`visualPanOffset`) so the editor and preview never cross-jump. Thread `CanvasTransform` through `FlowchartEditCanvas` (which already uses the centered-`DiagramView` model — a natural fit); wrap the custom-layout Gantt/Sequence canvases and the read-only fallback in a `.scaleEffect`/`.offset` container.

**Tech Stack:** Swift 6, SwiftUI, SwiftPM. Target: `DiagramKitSample` (Apple-only executable). Tests: XCTest under `Tests/DiagramKitTests` (that target already `@testable import`s `DiagramKitSample`).

## Global Constraints

- **Scope is `Sources/DiagramKitSample/` only.** No library-target or public-API changes.
- **No corpus snapshot changes.** The sample app is outside the `CorpusSnapshotTests` gate; do not record or rebaseline snapshots.
- **Zoom bounds:** min scale `0.25`, max scale `4.0` (match the existing `PreviewCanvas` constants).
- **Independent per-surface values:** editor uses `visualZoomScale`/`visualPanOffset`; preview keeps `zoomScale`/`panOffset`. Never share the *values*.
- **Work commit-by-commit on `main`** (repo standing default; no branches/worktrees).
- **File-size gate:** 500-line warning / 1000-line error per Swift file (`Scripts/check-file-sizes.sh`). `FlowchartEditCanvas.swift` is ~480 lines — keep new logic in shared helpers, not inline.
- **Test commands must use `--filter`** with an exact suite name (never a bare substring); full `swift test` runs are disallowed here.
- **Existing tests must stay green:** `TapCoordinateConversionTests` pins the current transform math — the `CanvasTransform` refactor must not break it.

---

## File Structure

**New files**
- `Sources/DiagramKitSample/Models/Workspace/CanvasTransform.swift` — pure value type: origin/viewRect/diagramPoint/fitScale/clampScale/gestureScale.
- `Sources/DiagramKitSample/Views/CanvasZoomToolbar.swift` — generalized floating zoom controls (was `PreviewToolbar`).
- `Sources/DiagramKitSample/Views/Visual/ZoomableCanvas.swift` — reusable container that wraps custom-layout content in pinch + background-pan + `.scaleEffect`/`.offset` + the shared toolbar (used by Gantt, Sequence, and the read-only fallback). Flowchart does **not** use it — it threads `CanvasTransform` internally because its overlays need per-element transform.
- `Tests/DiagramKitTests/CanvasTransformTests.swift` — unit tests for `CanvasTransform`.

**Modified files**
- `Sources/DiagramKitSample/Models/LiveEditorStore+Inspector.swift` — delegate `tapPointInDiagramCoordinates` to `CanvasTransform`.
- `Sources/DiagramKitSample/Models/LiveEditorState.swift` — add `visualZoomScale`/`visualPanOffset` (stored props, init params, decode).
- `Sources/DiagramKitSample/Models/LiveEditorStore.swift` — add `setVisualZoomScale`/`setVisualPanOffset`.
- `Sources/DiagramKitSample/Models/Workspace/WorkspaceMode.swift` — default `.split` → `.visual`.
- `Sources/DiagramKitSample/Views/PreviewCanvas.swift` — use `CanvasZoomToolbar`; use `CanvasTransform` static gesture-scale.
- `Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift` — thread `CanvasTransform`; add pinch + empty-drag pan + toolbar.
- `Sources/DiagramKitSample/Views/Visual/SubgraphOverlay.swift` — accept a `CanvasTransform`.
- `Sources/DiagramKitSample/Views/Visual/Gantt/GanttEditCanvas.swift` — `.scaleEffect`/`.offset` wrapper + toolbar.
- `Sources/DiagramKitSample/Views/Visual/Sequence/SequenceEditCanvas.swift` — `.scaleEffect`/`.offset` wrapper + toolbar.
- `Sources/DiagramKitSample/Views/Visual/VisualPane.swift` — wrap the read-only fallback `DiagramView` in the zoom container.
- `Tests/DiagramKitTests/LiveEditorStateCodecTests.swift` — assert the new fields round-trip and default to nil.

---

## Task 1: `CanvasTransform` pure value type

**Files:**
- Create: `Sources/DiagramKitSample/Models/Workspace/CanvasTransform.swift`
- Modify: `Sources/DiagramKitSample/Models/LiveEditorStore+Inspector.swift:74-88`
- Test: `Tests/DiagramKitTests/CanvasTransformTests.swift`

**Interfaces:**
- Produces:
  - `struct CanvasTransform: Equatable { var scale: CGFloat; var offset: CGSize }`
  - `static let CanvasTransform.minScale: CGFloat` = `0.25`, `static let maxScale: CGFloat` = `4.0`
  - `func origin(diagramBounds: CGRect, viewSize: CGSize) -> CGPoint`
  - `func viewRect(forDiagramBounds bounds: CGRect, diagramBounds: CGRect, viewSize: CGSize) -> CGRect`
  - `func diagramPoint(fromViewPoint point: CGPoint, diagramBounds: CGRect, viewSize: CGSize) -> CGPoint`
  - `static func clampScale(_ scale: CGFloat) -> CGFloat`
  - `static func fitScale(diagramBounds: CGRect, viewSize: CGSize, margin: CGFloat = 0.92) -> CGFloat`
  - `static func gestureScale(base: CGFloat, value: CGFloat) -> CGFloat`

- [ ] **Step 1: Write the failing tests**

Create `Tests/DiagramKitTests/CanvasTransformTests.swift`:

```swift
#if canImport(CoreGraphics)
import CoreGraphics
import XCTest
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
final class CanvasTransformTests: XCTestCase {

    private let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    private let view = CGSize(width: 400, height: 300)

    func test_identity_diagramPoint_matchesCenteringOffset() {
        // scale 1, no pan: diagram is centered; centering offset = (150, 100).
        // A tap at (170, 110) → (20, 10) in diagram-space.
        let t = CanvasTransform(scale: 1, offset: .zero)
        let p = t.diagramPoint(fromViewPoint: CGPoint(x: 170, y: 110),
                               diagramBounds: bounds, viewSize: view)
        XCTAssertEqual(p.x, 20, accuracy: 0.0001)
        XCTAssertEqual(p.y, 10, accuracy: 0.0001)
    }

    func test_zoomAndPan_diagramPoint_invertsForwardTransform() {
        // scale 2, pan (30, 20). Scaled 200x200, centering (100, 50),
        // origin = (130, 70). Tap (170, 90) → screen delta (40, 20) / 2 = (20, 10).
        let t = CanvasTransform(scale: 2, offset: CGSize(width: 30, height: 20))
        let p = t.diagramPoint(fromViewPoint: CGPoint(x: 170, y: 90),
                               diagramBounds: bounds, viewSize: view)
        XCTAssertEqual(p.x, 20, accuracy: 0.0001)
        XCTAssertEqual(p.y, 10, accuracy: 0.0001)
    }

    func test_viewRect_isInverseOfDiagramPoint() {
        // Forward then inverse must round-trip the element origin.
        let t = CanvasTransform(scale: 1.5, offset: CGSize(width: -12, height: 8))
        let element = CGRect(x: 20, y: 10, width: 40, height: 30)
        let rect = t.viewRect(forDiagramBounds: element, diagramBounds: bounds, viewSize: view)
        let backToDiagram = t.diagramPoint(fromViewPoint: CGPoint(x: rect.minX, y: rect.minY),
                                           diagramBounds: bounds, viewSize: view)
        XCTAssertEqual(backToDiagram.x, element.minX, accuracy: 0.0001)
        XCTAssertEqual(backToDiagram.y, element.minY, accuracy: 0.0001)
        XCTAssertEqual(rect.width, element.width * 1.5, accuracy: 0.0001)
        XCTAssertEqual(rect.height, element.height * 1.5, accuracy: 0.0001)
    }

    func test_clampScale_boundsToMinAndMax() {
        XCTAssertEqual(CanvasTransform.clampScale(0.1), 0.25, accuracy: 0.0001)
        XCTAssertEqual(CanvasTransform.clampScale(9), 4.0, accuracy: 0.0001)
        XCTAssertEqual(CanvasTransform.clampScale(1.5), 1.5, accuracy: 0.0001)
    }

    func test_fitScale_usesTightestAxisWithMargin() {
        // 100x100 in 400x300 with margin 0.92: min(400*.92/100, 300*.92/100)
        // = min(3.68, 2.76) = 2.76.
        let s = CanvasTransform.fitScale(diagramBounds: bounds, viewSize: view)
        XCTAssertEqual(s, 2.76, accuracy: 0.0001)
    }

    func test_gestureScale_multipliesAndClamps() {
        XCTAssertEqual(CanvasTransform.gestureScale(base: 1, value: 2), 2, accuracy: 0.0001)
        XCTAssertEqual(CanvasTransform.gestureScale(base: 3, value: 2), 4.0, accuracy: 0.0001) // clamped
    }
}
#endif
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter CanvasTransformTests`
Expected: FAIL — `cannot find 'CanvasTransform' in scope`.

- [ ] **Step 3: Create `CanvasTransform`**

Create `Sources/DiagramKitSample/Models/Workspace/CanvasTransform.swift`:

```swift
//
//  CanvasTransform.swift
//  DiagramPlayground
//
//  Pure centering + scale + offset math shared by every zoomable canvas
//  surface (preview + visual editors). The playground frames a diagram at
//  `diagramBounds * scale`, centers it inside the host view, then translates
//  by `offset`. This type is the single source of truth for that transform
//  and its inverse, so hit-testing-under-zoom is verifiable without any UI.
//

import CoreGraphics

struct CanvasTransform: Equatable {
    /// User zoom factor (1 = actual size).
    var scale: CGFloat
    /// Pan translation applied after centering.
    var offset: CGSize

    static let minScale: CGFloat = 0.25
    static let maxScale: CGFloat = 4.0

    /// Top-left of the scaled diagram in view-space.
    func origin(diagramBounds: CGRect, viewSize: CGSize) -> CGPoint {
        let scaledWidth = diagramBounds.width * scale
        let scaledHeight = diagramBounds.height * scale
        return CGPoint(
            x: (viewSize.width - scaledWidth) / 2 + offset.width,
            y: (viewSize.height - scaledHeight) / 2 + offset.height
        )
    }

    /// Diagram-space rect → view-space rect.
    func viewRect(forDiagramBounds bounds: CGRect, diagramBounds: CGRect, viewSize: CGSize) -> CGRect {
        let o = origin(diagramBounds: diagramBounds, viewSize: viewSize)
        return CGRect(
            x: o.x + bounds.minX * scale,
            y: o.y + bounds.minY * scale,
            width: bounds.width * scale,
            height: bounds.height * scale
        )
    }

    /// View-space point → diagram-space point (inverse of `viewRect`'s origin).
    func diagramPoint(fromViewPoint point: CGPoint, diagramBounds: CGRect, viewSize: CGSize) -> CGPoint {
        let o = origin(diagramBounds: diagramBounds, viewSize: viewSize)
        return CGPoint(x: (point.x - o.x) / scale, y: (point.y - o.y) / scale)
    }

    static func clampScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minScale), maxScale)
    }

    /// Fit-to-view scale with breathing room on the tightest axis.
    static func fitScale(diagramBounds: CGRect, viewSize: CGSize, margin: CGFloat = 0.92) -> CGFloat {
        guard diagramBounds.width > 0, diagramBounds.height > 0 else { return 1 }
        let scaleX = (viewSize.width * margin) / diagramBounds.width
        let scaleY = (viewSize.height * margin) / diagramBounds.height
        return clampScale(min(scaleX, scaleY))
    }

    /// New scale for a magnification gesture value against a base scale.
    static func gestureScale(base: CGFloat, value: CGFloat) -> CGFloat {
        clampScale(base * value)
    }
}
```

- [ ] **Step 4: Delegate the existing static helper to `CanvasTransform`**

In `Sources/DiagramKitSample/Models/LiveEditorStore+Inspector.swift`, replace the body of `tapPointInDiagramCoordinates` (lines 74-88) with a delegation so the existing `TapCoordinateConversionTests` stay green:

```swift
    nonisolated public static func tapPointInDiagramCoordinates(
        viewPoint: CGPoint,
        viewSize: CGSize,
        diagramBounds: CGRect,
        zoomScale: CGFloat,
        panOffset: CGSize
    ) -> CGPoint {
        CanvasTransform(scale: zoomScale, offset: panOffset)
            .diagramPoint(fromViewPoint: viewPoint, diagramBounds: diagramBounds, viewSize: viewSize)
    }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter CanvasTransformTests`
Expected: PASS (6 tests).

Run: `swift test --filter TapCoordinateConversionTests`
Expected: PASS (3 tests) — the delegation preserved behavior.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSample/Models/Workspace/CanvasTransform.swift \
        Sources/DiagramKitSample/Models/LiveEditorStore+Inspector.swift \
        Tests/DiagramKitTests/CanvasTransformTests.swift
git commit -m "Add CanvasTransform value type; delegate tap-coordinate math to it"
```

---

## Task 2: Independent per-surface zoom/pan state

**Files:**
- Modify: `Sources/DiagramKitSample/Models/LiveEditorState.swift:54-58, 143-170, decode block`
- Modify: `Sources/DiagramKitSample/Models/LiveEditorStore.swift:460-470`
- Test: `Tests/DiagramKitTests/LiveEditorStateCodecTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `LiveEditorState.visualZoomScale: CGFloat?` (default `nil`)
  - `LiveEditorState.visualPanOffset: CGSize?` (default `nil`)
  - `LiveEditorStore.setVisualZoomScale(_ scale: CGFloat?)`
  - `LiveEditorStore.setVisualPanOffset(_ offset: CGSize?)`

- [ ] **Step 1: Write the failing test**

Open `Tests/DiagramKitTests/LiveEditorStateCodecTests.swift` and add this test method inside the existing test class (match its `import`/`@available` header):

```swift
    func test_visualZoomPan_defaultsNilAndRoundTrips() throws {
        var state = LiveEditorState()
        XCTAssertNil(state.visualZoomScale)
        XCTAssertNil(state.visualPanOffset)

        state.visualZoomScale = 1.75
        state.visualPanOffset = CGSize(width: 12, height: -8)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(LiveEditorState.self, from: data)
        XCTAssertEqual(decoded.visualZoomScale, 1.75)
        XCTAssertEqual(decoded.visualPanOffset, CGSize(width: 12, height: -8))
    }

    func test_visualZoomPan_absentKeysDecodeToNil() throws {
        // A payload from before these fields existed must still decode.
        let legacy = "{}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LiveEditorState.self, from: legacy)
        XCTAssertNil(decoded.visualZoomScale)
        XCTAssertNil(decoded.visualPanOffset)
    }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter LiveEditorStateCodecTests`
Expected: FAIL — `value of type 'LiveEditorState' has no member 'visualZoomScale'`.

> If `test_visualZoomPan_absentKeysDecodeToNil` fails to compile because `LiveEditorState` requires more keys than `{}`, replace `"{}"` with the JSON produced by `try JSONEncoder().encode(LiveEditorState())` in a scratch step and trim the two visual keys — but the existing decode uses `decodeIfPresent` throughout, so `{}` is expected to work.

- [ ] **Step 3: Add the stored properties, init params, and decode**

In `Sources/DiagramKitSample/Models/LiveEditorState.swift`, after the existing `panOffset` property (line 58):

```swift
    /// Last user-set zoom scale for the visual editor canvas (nil = fit-to-view).
    /// Independent from `zoomScale`, which drives the preview canvas.
    public var visualZoomScale: CGFloat?

    /// Last user-set pan offset for the visual editor canvas. Independent
    /// from `panOffset`, which drives the preview canvas.
    public var visualPanOffset: CGSize?
```

Add init params after `panOffset: CGSize? = nil,` (line 152):

```swift
        visualZoomScale: CGFloat? = nil,
        visualPanOffset: CGSize? = nil,
```

Assign them in the init body next to the existing `self.panOffset = panOffset` assignment:

```swift
        self.visualZoomScale = visualZoomScale
        self.visualPanOffset = visualPanOffset
```

Add to the `Decodable` init next to the existing `panOffset` decode (mirror its exact style — the file uses `decodeIfPresent`):

```swift
        self.visualZoomScale = try c.decodeIfPresent(CGFloat.self, forKey: .visualZoomScale)
        self.visualPanOffset = try c.decodeIfPresent(CGSize.self, forKey: .visualPanOffset)
```

Add the two cases to the `CodingKeys` enum next to `case panOffset`:

```swift
        case visualZoomScale
        case visualPanOffset
```

> If the file also has an explicit `encode(to:)` (grep for `func encode(to`), add the mirror lines there:
> `try c.encodeIfPresent(visualZoomScale, forKey: .visualZoomScale)` and
> `try c.encodeIfPresent(visualPanOffset, forKey: .visualPanOffset)`.
> If encoding is synthesized (no explicit `encode`), skip this.

- [ ] **Step 4: Add the store setters**

In `Sources/DiagramKitSample/Models/LiveEditorStore.swift`, directly after `setPreviewPanOffset` (line 470):

```swift
    /// Persist the current visual-editor zoom scale.
    public func setVisualZoomScale(_ scale: CGFloat?) {
        state.visualZoomScale = scale
    }

    /// Persist the current visual-editor pan offset.
    public func setVisualPanOffset(_ offset: CGSize?) {
        state.visualPanOffset = offset
    }
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `swift test --filter LiveEditorStateCodecTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSample/Models/LiveEditorState.swift \
        Sources/DiagramKitSample/Models/LiveEditorStore.swift \
        Tests/DiagramKitTests/LiveEditorStateCodecTests.swift
git commit -m "Add independent visual-editor zoom/pan state + store setters"
```

---

## Task 3: Default workspace mode → Editor

**Files:**
- Modify: `Sources/DiagramKitSample/Models/Workspace/WorkspaceMode.swift:17`
- Test: `Tests/DiagramKitTests/WorkspaceModeDefaultTests.swift` (create)

**Interfaces:**
- Consumes: `WorkspaceMode`, `LiveEditorState`.
- Produces: `WorkspaceMode.default == .visual`.

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/WorkspaceModeDefaultTests.swift`:

```swift
import XCTest
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
final class WorkspaceModeDefaultTests: XCTestCase {

    func test_defaultWorkspaceModeIsEditor() {
        XCTAssertEqual(WorkspaceMode.default, .visual)
        XCTAssertEqual(WorkspaceMode.visual.label, "Editor")
    }

    func test_freshStateOpensInEditorMode() {
        XCTAssertEqual(LiveEditorState().workspaceMode, .visual)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter WorkspaceModeDefaultTests`
Expected: FAIL — `.split` != `.visual`.

- [ ] **Step 3: Flip the default**

In `Sources/DiagramKitSample/Models/Workspace/WorkspaceMode.swift`, change line 17:

```swift
    public static let `default`: WorkspaceMode = .visual
```

Update the stale comment at the top of the file (lines 6-7) to reflect the new default:

```swift
//  Drives the v2 Titlebar mode picker (Code / Editor / Split).
//  Default is `.visual` (the Editor canvas) so a fresh launch lands on
//  the visual editor.
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter WorkspaceModeDefaultTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Models/Workspace/WorkspaceMode.swift \
        Tests/DiagramKitTests/WorkspaceModeDefaultTests.swift
git commit -m "Default the playground workspace to the Editor (visual) mode"
```

---

## Task 4: Generalize `PreviewToolbar` → `CanvasZoomToolbar`

**Files:**
- Create: `Sources/DiagramKitSample/Views/CanvasZoomToolbar.swift` (moved/renamed from `PreviewToolbar.swift`)
- Delete: `Sources/DiagramKitSample/Views/PreviewToolbar.swift`
- Modify: `Sources/DiagramKitSample/Views/PreviewCanvas.swift:109-132, 235-287`

**Interfaces:**
- Consumes: `DiagramTheme`, `CanvasTransform` (from Task 1).
- Produces:
  - `struct CanvasZoomToolbar: View` with the same stored properties as today's `PreviewToolbar`, plus two optionals that let the editor drop preview-only controls:
    - `var showsGrid: Bool = true`
    - the existing `onFullWindowPreview: (() -> Void)?` already makes the full-window button optional.
  - The `gridEnabled` binding becomes optional: `@Binding var gridEnabled: Bool` → keep required; when `showsGrid == false` the grid button is omitted.

This task is a **pure refactor** — the preview must look and behave identically.

- [ ] **Step 1: Create `CanvasZoomToolbar` from `PreviewToolbar`**

Copy `Sources/DiagramKitSample/Views/PreviewToolbar.swift` to `Sources/DiagramKitSample/Views/CanvasZoomToolbar.swift`. Rename the struct and file header:

```swift
//
//  CanvasZoomToolbar.swift
//  DiagramPlayground
//
//  Floating zoom control cluster shared by the preview canvas and the
//  visual editor canvases: fit, zoom in/out, percent readout, actual size,
//  and (preview only) pan/grid toggles + full-window.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

struct CanvasZoomToolbar: View {
    let theme: DiagramTheme
    @Binding var zoomScale: CGFloat
    @Binding var gridEnabled: Bool
    @Binding var panZoomEnabled: Bool
    let isAtAutomaticFit: Bool
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let onFitToView: () -> Void
    let onActualSize: () -> Void
    let onFullWindowPreview: (() -> Void)?
    /// When false, the grid toggle is omitted (visual editor has no grid).
    var showsGrid: Bool = true
```

Keep the entire `body` and every private button computed property **unchanged**, except wrap the grid button in the `body`'s `HStack` behind the flag:

```swift
            actualSizeButton
            divider
            panZoomToggleButton
            if showsGrid {
                gridToggleButton
            }
            if onFullWindowPreview != nil {
                divider
                fullWindowButton
            }
```

- [ ] **Step 2: Delete the old file**

```bash
git rm Sources/DiagramKitSample/Views/PreviewToolbar.swift
```

- [ ] **Step 3: Repoint `PreviewCanvas`**

In `Sources/DiagramKitSample/Views/PreviewCanvas.swift`, change the `PreviewToolbar(` call (line 109) to `CanvasZoomToolbar(` — the argument list is unchanged (preview keeps grid + full-window, so `showsGrid` defaults to `true`).

Then replace the local `static func zoomScale(forGestureValue:...)` (lines 280-287) usage in `magnificationGesture` with the shared helper. In `magnificationGesture` (line 242) change:

```swift
                setZoomScale(CanvasTransform.gestureScale(base: baseScale, value: value))
```

and delete the now-unused `static func zoomScale(forGestureValue:baseScale:minZoom:maxZoom:)` (lines 280-287) plus its `minZoom`/`maxZoom` params, since `CanvasTransform.gestureScale` clamps to the same bounds. (Leave `minZoom`/`maxZoom` stored properties in `PreviewCanvas` — they're still used by `currentZoomScale`, `calculateFitScale`, and the toolbar.)

> If any test references `PreviewCanvas.zoomScale(forGestureValue:...)`, keep the static method as a one-line delegate to `CanvasTransform.gestureScale` instead of deleting it. Grep first: `grep -rn "zoomScale(forGestureValue" Tests Sources`.

- [ ] **Step 4: Build to verify the refactor compiles**

Run: `swift build`
Expected: builds with no errors.

- [ ] **Step 5: Run the preview coordinate test as a regression guard**

Run: `swift test --filter TapCoordinateConversionTests`
Expected: PASS (unchanged behavior).

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSample/Views/CanvasZoomToolbar.swift \
        Sources/DiagramKitSample/Views/PreviewCanvas.swift
git commit -m "Generalize PreviewToolbar into shared CanvasZoomToolbar"
```

---

## Task 5: Thread `CanvasTransform` through `FlowchartEditCanvas` (identity refactor)

**Files:**
- Modify: `Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift:46-114, 118-139, 259-266`
- Modify: `Sources/DiagramKitSample/Views/Visual/SubgraphOverlay.swift:17-64`

**Interfaces:**
- Consumes: `CanvasTransform`, `LiveEditorState.visualZoomScale`/`visualPanOffset`.
- Produces: a private `FlowchartEditCanvas.transform` computed property and transform-aware `viewRect`/`diagramPoint`/`centerPoint`.

This task changes the *geometry plumbing only*; with `scale == 1` and `offset == .zero` the canvas renders and hit-tests exactly as before. No gesture behavior changes yet.

- [ ] **Step 1: Add a `transform` computed property**

In `FlowchartEditCanvas` (after the `@State` declarations, near line 45), add:

```swift
    /// Committed zoom/pan for the visual editor, resolved to a `CanvasTransform`.
    /// Task 6 adds live gesture translation on top of this.
    private var transform: CanvasTransform {
        CanvasTransform(
            scale: store.state.visualZoomScale ?? 1,
            offset: store.state.visualPanOffset ?? .zero
        )
    }
```

- [ ] **Step 2: Route the coordinate helpers through `transform`**

Replace `viewRect(for:in:)` (lines 130-139):

```swift
    private func viewRect(for diagramBounds: DiagramRect, in viewSize: CGSize) -> CGRect {
        transform.viewRect(
            forDiagramBounds: CGRect(
                x: CGFloat(diagramBounds.minX), y: CGFloat(diagramBounds.minY),
                width: CGFloat(diagramBounds.width), height: CGFloat(diagramBounds.height)
            ),
            diagramBounds: liveDiagramBounds,
            viewSize: viewSize
        )
    }
```

Replace `diagramPoint(from:viewSize:)` (lines 259-266):

```swift
    private func diagramPoint(from viewPoint: CGPoint, viewSize: CGSize) -> DiagramPoint {
        let p = transform.diagramPoint(
            fromViewPoint: viewPoint, diagramBounds: liveDiagramBounds, viewSize: viewSize
        )
        return DiagramPoint(x: Double(p.x), y: Double(p.y))
    }
```

- [ ] **Step 3: Scale + offset the `DiagramView` frame and position**

In `body` (lines 52-62), replace the `DiagramView` frame/position modifiers so the painted diagram matches the transform. Change:

```swift
                DiagramView(
                    source: store.previewSource,
                    theme: store.previewTheme,
                    layoutConfig: store.previewLayoutConfig,
                    sourceFormat: store.state.sourceFormat.formatID,
                    parseError: parseErrorBinding,
                    diagramBounds: $liveDiagramBounds,
                    boundsLookup: $liveBoundsLookup
                )
                .frame(
                    width: max(liveDiagramBounds.width * transform.scale, 1),
                    height: max(liveDiagramBounds.height * transform.scale, 1)
                )
                .position(diagramCenter(in: geometry.size))
```

Replace `centerPoint(in:)` (lines 118-120) with a transform-aware center (the `.position` sets the *center* of the scaled frame, which is `origin + scaledSize/2`):

```swift
    private func diagramCenter(in viewSize: CGSize) -> CGPoint {
        let o = transform.origin(diagramBounds: liveDiagramBounds, viewSize: viewSize)
        return CGPoint(
            x: o.x + liveDiagramBounds.width * transform.scale / 2,
            y: o.y + liveDiagramBounds.height * transform.scale / 2
        )
    }
```

Delete the old `centerPoint(in:)` (it is now unused — grep to confirm no other caller: `grep -n "centerPoint" Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift`).

- [ ] **Step 4: Make `SubgraphOverlay` transform-aware**

In `Sources/DiagramKitSample/Views/Visual/SubgraphOverlay.swift`, add a `transform` input (line ~17, next to `viewSize`):

```swift
    let transform: CanvasTransform
```

Replace its centering math (lines 59-64) to use the transform:

```swift
        let o = transform.origin(diagramBounds: liveDiagramBounds, viewSize: viewSize)
        let rect = CGRect(
            x: o.x + CGFloat(union.minX) * transform.scale - padding,
            y: o.y + CGFloat(union.minY) * transform.scale - padding,
            width: CGFloat(union.width) * transform.scale + padding * 2,
            height: CGFloat(union.height) * transform.scale + padding * 2
        )
```

> Read the full `SubgraphOverlay.swift` first; apply the `* transform.scale` factor to every width/height and the `+ o` shift to every x/y that currently uses `centerX`/`centerY`. The `padding` term is a fixed view-space inset — do **not** scale it.

Update the call site in `FlowchartEditCanvas.body` (line 74):

```swift
                SubgraphOverlay(
                    store: store,
                    viewSize: geometry.size,
                    liveDiagramBounds: liveDiagramBounds,
                    liveBoundsLookup: liveBoundsLookup,
                    transform: transform
                )
```

- [ ] **Step 5: Build and verify identity behavior**

Run: `swift build`
Expected: builds clean.

Run: `swift run DiagramKitSample`
Expected: the app opens on the **Editor** tab (from Task 3); the flowchart renders centered exactly as before; tapping a node selects it and the accent ring lines up (scale is still 1, so no visual change). Close the app.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift \
        Sources/DiagramKitSample/Views/Visual/SubgraphOverlay.swift
git commit -m "Thread CanvasTransform through the flowchart edit canvas (identity)"
```

---

## Task 6: Flowchart canvas — pinch zoom, empty-drag pan, and toolbar

**Files:**
- Modify: `Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift` (add gesture state, gestures, live-pan, toolbar overlay; extend `transform`)

**Interfaces:**
- Consumes: `CanvasZoomToolbar` (Task 4), `CanvasTransform` (Task 1), `store.setVisualZoomScale`/`setVisualPanOffset` (Task 2).
- Produces: a fully zoomable/pannable flowchart editor.

- [ ] **Step 1: Add gesture + live-transform state**

Add these `@State` properties to `FlowchartEditCanvas` (near line 45):

```swift
    // Zoom / pan gesture state (visual editor plan — canvas zoom).
    @SwiftUI.State private var automaticZoomScale: CGFloat = 1.0
    @SwiftUI.State private var gestureBaseZoomScale: CGFloat?
    @SwiftUI.State private var activePanTranslation: CGSize = .zero
    private let minZoom: CGFloat = CanvasTransform.minScale
    private let maxZoom: CGFloat = CanvasTransform.maxScale
```

- [ ] **Step 2: Make `transform` include live translation and auto-fit**

Replace the Task-5 `transform` property so it folds in the active gesture translation and the auto-fit fallback:

```swift
    private var currentZoomScale: CGFloat {
        CanvasTransform.clampScale(store.state.visualZoomScale ?? automaticZoomScale)
    }

    private var transform: CanvasTransform {
        let base = store.state.visualPanOffset ?? .zero
        return CanvasTransform(
            scale: currentZoomScale,
            offset: CGSize(
                width: base.width + activePanTranslation.width,
                height: base.height + activePanTranslation.height
            )
        )
    }

    private var isAtAutomaticFit: Bool { store.state.visualZoomScale == nil }
```

- [ ] **Step 3: Add pinch gesture + refresh auto-fit on bounds/size change**

In `body`, add a magnification gesture to the interaction stack (alongside the existing `.gesture`/`.simultaneousGesture` chain around line 98) and auto-fit refresh `onChange`. Add after the existing `.onChange(of: liveDiagramBounds)` (line 109):

```swift
            .simultaneousGesture(magnificationGesture)
            .onChange(of: liveDiagramBounds) { _, newBounds in
                refreshAutomaticFit(bounds: newBounds, viewSize: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                refreshAutomaticFit(bounds: liveDiagramBounds, viewSize: newSize)
            }
```

Add these helpers to the type:

```swift
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if gestureBaseZoomScale == nil { gestureBaseZoomScale = currentZoomScale }
                let base = gestureBaseZoomScale ?? currentZoomScale
                store.setVisualZoomScale(CanvasTransform.gestureScale(base: base, value: value))
            }
            .onEnded { _ in gestureBaseZoomScale = nil }
    }

    private func refreshAutomaticFit(bounds: CGRect, viewSize: CGSize) {
        guard bounds.width > 0, viewSize.width > 0 else { return }
        automaticZoomScale = CanvasTransform.fitScale(diagramBounds: bounds, viewSize: viewSize)
    }
```

- [ ] **Step 4: Wire empty-space drag → pan**

In `handleDragChanged` (lines 280-311), the `.select` case currently no-ops on empty-canvas drags and the `.pan` case is empty. Route empty-canvas drags (and the pan tool) to live pan. Replace the `.select` and `.pan` cases:

```swift
        case .select:
            if nodeDragElementID == nil {
                guard
                    let elementID = nodeID(at: value.startLocation, in: viewSize),
                    elementID.hasPrefix("node:")
                else {
                    // Drag began on empty canvas → pan the view.
                    activePanTranslation = value.translation
                    break
                }
                nodeDragElementID = elementID
            }
            nodeDragCurrent = value.location
            dropTargetGroupID = groupID(at: value.location, in: viewSize)
        case .pan:
            activePanTranslation = value.translation
```

In `handleDragEnded` (lines 313-334), commit the pan for both cases. Replace the `.select` and `.pan` cases:

```swift
        case .select:
            if nodeDragElementID != nil {
                commitNodeDrag(end: value.location, viewSize: viewSize)
            } else {
                commitPan(value.translation)
            }
        case .pan:
            commitPan(value.translation)
```

Add the commit helper:

```swift
    private func commitPan(_ translation: CGSize) {
        let base = store.state.visualPanOffset ?? .zero
        store.setVisualPanOffset(CGSize(
            width: base.width + translation.width,
            height: base.height + translation.height
        ))
        activePanTranslation = .zero
    }
```

> Note the `defer` block in `handleDragEnded` already resets `nodeDragElementID`/`nodeDragCurrent`; leave it. `activePanTranslation` is reset inside `commitPan`.

- [ ] **Step 5: Overlay the zoom toolbar**

In `body`, add a bottom-trailing toolbar overlay. Insert before `.accessibilityIdentifier(A11yID.Visual.canvas)` (line 113), attached to the outer `GeometryReader` content:

```swift
            .overlay(alignment: .bottomTrailing) {
                CanvasZoomToolbar(
                    theme: store.previewTheme,
                    zoomScale: zoomToolbarBinding,
                    gridEnabled: .constant(false),
                    panZoomEnabled: .constant(true),
                    isAtAutomaticFit: isAtAutomaticFit,
                    minZoom: minZoom,
                    maxZoom: maxZoom,
                    onFitToView: {
                        store.setVisualZoomScale(nil)
                        store.setVisualPanOffset(.zero)
                    },
                    onActualSize: {
                        store.setVisualZoomScale(1.0)
                        store.setVisualPanOffset(.zero)
                    },
                    onFullWindowPreview: nil,
                    showsGrid: false
                )
                .padding(12)
            }
```

Add the toolbar binding:

```swift
    private var zoomToolbarBinding: Binding<CGFloat> {
        Binding(
            get: { currentZoomScale },
            set: { store.setVisualZoomScale(CanvasTransform.clampScale($0)) }
        )
    }
```

> The toolbar's `panZoomToggleButton` binds to `.constant(true)` here (the visual editor is always interactive); the toggle renders but is inert. If a dead toggle is undesirable, this is acceptable for v1 — the button still reflects "on". A follow-up can hide it via a `showsPanToggle` flag mirroring `showsGrid`.

- [ ] **Step 6: Build and manually verify**

Run: `swift build`
Expected: clean.

Run: `swift run DiagramKitSample`
Expected on the Editor tab with a flowchart:
- Pinch (trackpad) zooms the diagram; the selection ring stays aligned to nodes after zoom.
- Dragging empty canvas pans; dragging a node still moves/joins it.
- Toolbar `+`/`−` zoom, `Fit` re-fits, `1:1` returns to 100%.
- Cmd `=`/`−`/`0`/`1` shortcuts (wired inside `CanvasZoomToolbar`) work while the canvas is focused.
Close the app.

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift
git commit -m "Add pinch zoom, empty-drag pan, and zoom toolbar to the flowchart editor"
```

---

## Task 7: Shared `ZoomableCanvas` container + Gantt canvas

**Files:**
- Create: `Sources/DiagramKitSample/Views/Visual/ZoomableCanvas.swift`
- Modify: `Sources/DiagramKitSample/Views/Visual/Gantt/GanttEditCanvas.swift`

**Interfaces:**
- Consumes: `CanvasZoomToolbar`, `CanvasTransform`, `store.setVisualZoomScale`/`setVisualPanOffset`.
- Produces:
  - `struct ZoomableCanvas<Content: View>: View` — `init(store: LiveEditorStore, @ViewBuilder content: () -> Content)`.
  - A zoomable/pannable Gantt editor built on it.

**Why a container here (not for Flowchart):** Gantt/Sequence draw custom layouts (not the centered `DiagramView`), so the whole content can be transformed with `.scaleEffect(anchor: .topLeading).offset(...)`. Content-level drags (bar resize / row reorder) stay **inside** the content and receive pre-effect local coordinates, so they need no change. Pan is a drag on the **background** layer behind the content (empty areas fall through to it; drawn bars/rows win via topmost hit-testing). This container collapses the otherwise-identical gesture/toolbar wiring into one place. Flowchart can't use it — its overlays need per-element `CanvasTransform`, which Task 5/6 thread in directly.

- [ ] **Step 1: Create the `ZoomableCanvas` container**

Create `Sources/DiagramKitSample/Views/Visual/ZoomableCanvas.swift`:

```swift
//
//  ZoomableCanvas.swift
//  DiagramPlayground
//
//  Reusable pinch + background-pan + toolbar wrapper for custom-layout
//  visual editors (Gantt, Sequence) and the read-only fallback. Applies a
//  `.scaleEffect`/`.offset` transform to its content and binds the shared
//  `CanvasZoomToolbar` to the visual-editor zoom state. Fit / Actual reset
//  to identity (these layouts already fill the available width).
//
//  Flowchart does NOT use this — it threads `CanvasTransform` through its
//  own overlays for per-element hit-testing.
//

import SwiftUI

struct ZoomableCanvas<Content: View>: View {
    @Bindable var store: LiveEditorStore
    @ViewBuilder var content: () -> Content

    @SwiftUI.State private var gestureBaseZoomScale: CGFloat?
    @SwiftUI.State private var activePanTranslation: CGSize = .zero

    private var currentZoomScale: CGFloat {
        CanvasTransform.clampScale(store.state.visualZoomScale ?? 1)
    }
    private var effectiveOffset: CGSize {
        let base = store.state.visualPanOffset ?? .zero
        return CGSize(width: base.width + activePanTranslation.width,
                      height: base.height + activePanTranslation.height)
    }
    private var isAtAutomaticFit: Bool { store.state.visualZoomScale == nil }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(store.previewTheme.background)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .gesture(panGesture)
                .simultaneousGesture(magnificationGesture)

            content()
                .scaleEffect(currentZoomScale, anchor: .topLeading)
                .offset(effectiveOffset)
        }
        .overlay(alignment: .bottomTrailing) { toolbar }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if gestureBaseZoomScale == nil { gestureBaseZoomScale = currentZoomScale }
                let base = gestureBaseZoomScale ?? currentZoomScale
                store.setVisualZoomScale(CanvasTransform.gestureScale(base: base, value: value))
            }
            .onEnded { _ in gestureBaseZoomScale = nil }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in activePanTranslation = value.translation }
            .onEnded { value in
                let base = store.state.visualPanOffset ?? .zero
                store.setVisualPanOffset(CGSize(width: base.width + value.translation.width,
                                                height: base.height + value.translation.height))
                activePanTranslation = .zero
            }
    }

    private var toolbar: some View {
        CanvasZoomToolbar(
            theme: store.previewTheme,
            zoomScale: Binding(
                get: { currentZoomScale },
                set: { store.setVisualZoomScale(CanvasTransform.clampScale($0)) }
            ),
            gridEnabled: .constant(false),
            panZoomEnabled: .constant(true),
            isAtAutomaticFit: isAtAutomaticFit,
            minZoom: CanvasTransform.minScale,
            maxZoom: CanvasTransform.maxScale,
            onFitToView: { store.setVisualZoomScale(nil); store.setVisualPanOffset(.zero) },
            onActualSize: { store.setVisualZoomScale(1.0); store.setVisualPanOffset(.zero) },
            onFullWindowPreview: nil,
            showsGrid: false
        )
        .padding(12)
    }
}
```

- [ ] **Step 2: Wrap the Gantt canvas content**

In `Sources/DiagramKitSample/Views/Visual/Gantt/GanttEditCanvas.swift`, replace the `body`'s `ZStack` (lines 23-34) so the content routes through `ZoomableCanvas`:

```swift
        ZoomableCanvas(store: store) {
            if let diagram = ganttDiagram {
                GeometryReader { geo in
                    canvas(diagram: diagram, size: geo.size)
                }
            } else {
                missingDocumentPlaceholder
            }
        }
        .accessibilityIdentifier(A11yID.Visual.canvas)
```

The `ZoomableCanvas` supplies the background, so the standalone `Color(store.previewTheme.background)` layer that was at the top of the old `ZStack` is no longer needed there.

- [ ] **Step 3: Build and manually verify**

Run: `swift build`
Expected: clean.

Run: `swift run DiagramKitSample` → load a Gantt sample → switch to Editor:
- Pinch zooms; drag on empty band background pans; dragging a bar's end handle still resizes it (tooltip shows +Nw/−Nw).
- Toolbar `+`/`−`/`Fit`/`1:1` behave.
Close the app.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitSample/Views/Visual/ZoomableCanvas.swift \
        Sources/DiagramKitSample/Views/Visual/Gantt/GanttEditCanvas.swift
git commit -m "Add shared ZoomableCanvas container; apply it to the Gantt editor"
```

---

## Task 8: Sequence canvas + read-only fallback — reuse `ZoomableCanvas`

**Files:**
- Modify: `Sources/DiagramKitSample/Views/Visual/Sequence/SequenceEditCanvas.swift`
- Modify: `Sources/DiagramKitSample/Views/Visual/VisualPane.swift:148-158`

**Interfaces:**
- Consumes: `ZoomableCanvas` (Task 7).
- Produces: zoomable/pannable Sequence editor + zoomable read-only fallback.

**Approach:** the Sequence row-drag `DragGesture` is attached to each `messageRow` inside the content and uses `value.translation` (scale-relative), so it stays correct inside the `ZoomableCanvas` wrapper. This task is almost entirely reuse.

- [ ] **Step 1: Wrap the Sequence canvas content**

Read `SequenceEditCanvas.body` first. Wrap its top-level content in `ZoomableCanvas(store: store) { ... }`. If the body is (roughly):

```swift
        ZStack(alignment: .topLeading) {
            Color(store.previewTheme.background).ignoresSafeArea()
            if let diagram = sequenceDiagram {
                GeometryReader { geo in
                    canvas(actors: diagram.actors, messages: diagram.messages, size: geo.size)
                }
            } else {
                missingDocumentPlaceholder
            }
        }
        .accessibilityIdentifier(A11yID.Visual.canvas)
```

replace it with:

```swift
        ZoomableCanvas(store: store) {
            if let diagram = sequenceDiagram {
                GeometryReader { geo in
                    canvas(actors: diagram.actors, messages: diagram.messages, size: geo.size)
                }
            } else {
                missingDocumentPlaceholder
            }
        }
        .accessibilityIdentifier(A11yID.Visual.canvas)
```

Match the real property/accessor names in the file (e.g. the exact `sequenceDiagram` accessor and `canvas(...)` signature) — the shape above is illustrative; keep the file's actual bindings.

- [ ] **Step 2: Wrap the `VisualPane` read-only fallback**

In `Sources/DiagramKitSample/Views/Visual/VisualPane.swift`, the `family` fallback (lines 148-158) renders a bare read-only `DiagramView` when there is no editor. Replace the `else` branch so Editor mode still zooms during first render:

```swift
        } else {
            // No editor yet (parse not run). Reuse the preview surface, which
            // already carries the full zoom/pan/toolbar stack, so Editor mode
            // always supports zoom/pan even before the editor is populated.
            PreviewCanvas(store: store, onFullWindowPreview: nil)
        }
```

> This intentionally uses the *preview* zoom state for the transient read-only case (no editing occurs there), rather than introducing a fourth zoom surface. Acceptable per the spec's "wrap the fallback in the shared zoom container" intent.

- [ ] **Step 3: Build and manually verify**

Run: `swift build`
Expected: clean.

Run: `swift run DiagramKitSample`:
- Load a sequence sample → Editor: pinch zooms; empty-space drag pans; dragging a message row still reorders it.
- Load a family with no visual editor (e.g., pie) → Editor: the read-only fallback shows with working zoom controls.
Close the app.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitSample/Views/Visual/Sequence/SequenceEditCanvas.swift \
        Sources/DiagramKitSample/Views/Visual/VisualPane.swift
git commit -m "Reuse ZoomableCanvas for the sequence editor + read-only fallback"
```

---

## Deferred / Out of Scope

- **macOS scroll-wheel pan + ⌘-scroll zoom.** The spec's interaction list mentioned trackpad two-finger scroll-to-pan and ⌘-scroll-to-zoom. This plan delivers **pinch** (`MagnificationGesture`, which is the trackpad pinch on macOS), **drag-to-pan**, **keyboard** (⌘ `=`/`−`/`0`/`1`), and the **on-canvas toolbar** — which fully covers "gestures, keyboard shortcuts, and controls." Native scroll-wheel handling requires a bespoke `NSEvent.addLocalMonitorForEvents(matching: .scrollWheel)` monitor bridged through an `NSViewRepresentable`, which is macOS-only and coordinate-sensitive. It is deferred to a follow-up unless explicitly requested; nothing in this plan blocks adding it later.

## Final Verification

- [ ] **Run the full sample-app test slice** (targeted suites, per the no-full-run constraint):

```bash
swift test --filter CanvasTransformTests
swift test --filter TapCoordinateConversionTests
swift test --filter LiveEditorStateCodecTests
swift test --filter WorkspaceModeDefaultTests
swift build
```

Expected: all four suites PASS; build clean.

- [ ] **Manual end-to-end** (`swift run DiagramKitSample`):
  - App opens on the **Editor** tab.
  - Flowchart / Gantt / Sequence editors each support pinch-zoom, empty-space drag-pan, toolbar Fit/−/%/+/1:1, and Cmd `=`/`−`/`0`/`1`.
  - Switching to **Split** shows the preview with its own independent zoom (zooming the preview does not move the editor's zoom, and vice-versa).

- [ ] **File-size gate** (new gesture code lives in shared helpers, but confirm):

```bash
Scripts/check-file-sizes.sh
```

Expected: no new errors. If `FlowchartEditCanvas.swift` crosses 500 lines (warning) or any file crosses 1000 (error), extract the gesture helpers into a `FlowchartEditCanvas+Zoom.swift` extension before finishing.
